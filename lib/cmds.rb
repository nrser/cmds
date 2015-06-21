# stdlib
require 'shellwords'
require 'open3'
require 'erb'

# deps
require 'nrser'

# project
require "cmds/version"

class Cmds
  class Result
    attr_reader :cmd, :status, :out, :err

    def initialize cmd, status, out, err
      @cmd = cmd
      @status = status
      @out = out
      @err = err
    end

    def ok?
      @status == 0
    end

    def error?
      ! ok?
    end
  end

  class ERBContext
    def initialize args, kwargs
      @args = args
      @kwargs = kwargs
      @arg_index = 0
    end

    def method_missing sym, *args, &block
      if args.empty? && block.nil?
        if sym.to_s[-1] == '?'
          key = sym.to_s[0...-1].to_sym
          @kwargs[key]
        else
          @kwargs.fetch sym
        end
      else
        super
      end
    end

    def get_binding
      binding
    end

    def arg
      @args.fetch(@arg_index).tap {@arg_index += 1}
    end
  end

  # shortcut for Shellwords.escape
  # 
  # also makes it easier to change or customize or whatever
  def self.esc str
    Shellwords.escape str
  end

  # escape option hash.
  #
  # this is only useful for the two common option styles: 
  #
  # -   single character keys become `-<char> <value>`
  #
  #         {x: 1}    => "-x 1"
  # 
  # -   longer keys become `--<key>=<value>` options
  # 
  #         {blah: 2} => "--blah=2"
  #
  # if you have something else, you're going to have to just put it in
  # the cmd itself, like:
  # 
  #     Cmds "blah -assholeOptionOn:%{s}", "ok"
  # 
  # or whatever similar shit said command requires.
  #
  # however, if the value is an Array, it will repeat the option for each
  # value:
  # 
  #     {x:     [1, 2, 3]} => "-x 1 -x 2 -x 3"
  #     {blah:  [1, 2, 3]} => "--blah=1 --blah=2 --blah=3"
  # 
  # i can't think of any right now, but i swear i've seen commands that take
  # opts that way.
  # 
  def self.expand_option_hash hash
    hash.map {|key, values|
      # keys need to be strings
      key = key.to_s unless key.is_a? String

      [key, values]

    }.sort {|(key_a, values_a), (key_b, values_b)|
      # sort by the (now string) keys
      key_a <=> key_b

    }.map {|key, values|
      # for simplicity's sake, treat all values like an array
      values = [values] unless values.is_a? Array

      # keys of length 1 expand to `-x v` form
      expanded = if key.length == 1
        values.map {|value|
          if value.nil?
            "-#{ esc key }"
          else
            "-#{ esc key } #{ esc value}"
          end
        }

      # longer keys expand to `--key=value` form
      else
        values.map {|value|
          if value.nil?
            "--#{ esc key }"
          else
            "--#{ esc key }=#{ esc value }"
          end
        }
      end
    }.flatten.join ' '
  end # ::expand_option_hash

  # expand one of the substitutions
  def self.expand_sub sub
    case sub
    when Hash
      expand_option_hash sub
    else
      esc sub.to_s
    end
  end # ::expand_sub

  # substitute values into a command, escaping them for the shell and
  # offering convenient expansions for some structures.
  # 
  # `cmd` is a string that can be substituted via ruby's `%` operator, like
  # 
  #     "git diff %s"
  # 
  # for positional substitution, or 
  # 
  #     "git diff %{path}"
  # 
  # for keyword substitution.
  # 
  # `subs` is either:
  # 
  # -   an Array when `cmd` has positional placeholders
  # -   a Hash when `cmd` has keyword placeholders.
  # 
  # the elements of the `subs` array or values of the `subs` hash are:
  # 
  # -   strings that are substituted into `cmd` after being escaped:
  #     
  #         sub "git diff %{path}", path: "some path/to somewhere"
  #         # => 'git diff some\ path/to\ somewhere'
  # 
  # -   hashes that are expanded into options:
  #     
  #         sub "psql %{opts} %{database} < %{filepath}",
  #           database: "blah",
  #           filepath: "/where ever/it/is.psql",
  #           opts: {
  #             username: "bingo bob",
  #             host: "localhost",
  #             port: 12345,
  #           }
  #         # => 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  # 
  def self.sub cmd, subs
    args = []
    kwargs = {}

    case subs
    when Hash
      kwargs = subs.map {|key, sub|
        [key, expand_sub(sub)]
      }.to_h

    when Array
      args = subs.map {|sub| expand_sub sub }

    else
      raise TypeError.new "subs should be Hash or Array, not #{ subs.inspect }"

    end
    
    NRSER.squish ERB.new(cmd).result(ERBContext.new(args, kwargs).get_binding)
  end # ::sub

  # create a new Cmd from template and subs and call it
  def self.run template, subs = nil
    self.new(template, subs).call
  end

  def initialize template, subs = nil
    @template = template
    @subs = subs
  end #sub

  def call subs = nil
    subs = merge_subs subs

    cmd = if subs
      Cmds.sub @template, subs
    else
      @template
    end

    out, err, status = Open3.capture3 cmd

    Cmds::Result.new cmd, status, out, err
  end #call

  private

    def merge_subs to_merge
      # short-circuit when the arg is nil
      return @subs if to_merge.nil?

      case @subs
      when nil
        to_merge

      when Array
        unless to_merge.is_a? Array
          raise "can't merge non-array substitutions #{ to_merge.inspect } " +
            "with existing array #{ @subs.inspect }"
        end
        @subs + to_merge

      when Hash
        unless to_merge.is_a? Hash
          raise "can't merge non-hash substitutions #{ to_merge.inspect } " +
            "with existing hash #{ @subs.inspect }"
        end

        @subs.merge to_merge

      else
        raise "don't know how to handle #{ to_merge.class }: " + 
          "#{ to_merge.inspect }"

      end # case @subs
    end #merge_subs

  # end private
end # Cmds

# convenience for Cmds::run
def Cmds *args
  Cmds.run *args
end
