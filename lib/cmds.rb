# stdlib
require 'shellwords'
require 'open3'
require 'erubis'

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

  # extension of Erubis' EscapedEruby (which auto-escapes `<%= %>` and
  # leaves `<%== %>` raw) that calls `Cmds.expand_sub` on the value
  class ShellEruby < Erubis::EscapedEruby
    def escaped_expr code
      "::Cmds.expand_sub(#{code.strip})"
    end
  end

  class ERBContext < BasicObject
    def initialize args, kwds
      @args = args
      @kwds = kwds
      @arg_index = 0
    end

    def method_missing sym, *args, &block
      if args.empty? && block.nil?
        if sym.to_s[-1] == '?'
          key = sym.to_s[0...-1].to_sym
          @kwds[key]
        else
          @kwds.fetch sym
        end
      else
        super
      end
    end

    def get_binding
      ::Kernel.send :binding
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
    when nil
      # nil is just an empty string, NOT an empty string bash token
      ''
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
  def self.sub cmd, args = [], kwds = {}
    raise TypeError.new("args must be an Array") unless args.is_a? Array
    raise TypeError.new("kwds must be an Hash") unless kwds.is_a? Hash

    NRSER.squish ShellEruby.new(cmd).result(ERBContext.new(args, kwds).get_binding)
  end # ::sub

  def self.subs_to_args_and_kwds subs
    args = []
    kwds = {}

    case subs.length
    when 0
      # pass
    when 1
      case subs[0]
      when Hash
        kwds = subs[0]

      when Array
        args = subs[0]

      else
        raise TypeError.new NRSER.squish <<-BLOCK
          first *subs arg must be Array or Hash, not #{ subs[0].inspect }
        BLOCK
      end

    when 2
      unless subs[0].is_a? Array
        raise TypeError.new NRSER.squish <<-BLOCK
          first *subs arg needs to be an array, not #{ subs[0].inspect }
        BLOCK
      end

      unless subs[1].is_a? Hash
        raise TypeError.new NRSER.squish <<-BLOCK
          third *subs arg needs to be a Hash, not #{ subs[1].inspect }
        BLOCK
      end

      args, kwds = subs
    else
      raise ArgumentError.new NRSER.squish <<-BLOCK
        must provide one or two *subs arguments, received #{ 1 + subs.length }
      BLOCK
    end

    [args, kwds]
  end

  # create a new Cmd from template and subs and call it
  def self.run template, *subs
    self.new(template, *subs).call
  end

  def self.replace_shortcuts template
    template
      .gsub(
        # %s => <%= arg %>
        /(\A|[[:space:]])\%s(\Z|[[:space:]])/,
        '\1<%= arg %>\2'
      )
      .gsub(
        # %%s => %s
        /(\A|[[:space:]])\%\%s(\Z|[[:space:]])/,
        '\1%s\2'
      )
      .gsub(
        # %{key} => <%= key %>, %{key?} => <%= key? %>
        /(\A|[[:space:]])\%\{([a-zA-Z_]+\??)\}(\Z|[[:space:]])/,
        '\1<%= \2 %>\3'
      )
      .gsub(
        # %%{key} => %{key}, %%{key?} => %{key?}
        /(\A|[[:space:]])\%\%\{([a-zA-Z_]+\??)\}(\Z|[[:space:]])/,
        '\1%{\2}\3'
      )
      .gsub(
        # %<key>s => <%= key %>, %<key?>s => <%= key? %>
        /(\A|[[:space:]])\%\<([a-zA-Z_]+\??)\>s(\Z|[[:space:]])/,
        '\1<%= \2 %>\3'
      )
      .gsub(
        # %%<key>s => %<key>s, %%<key?>s => %<key?>s
        /(\A|[[:space:]])\%\%\<([a-zA-Z_]+\??)\>s(\Z|[[:space:]])/,
        '\1%<\2>s\3'
      )
  end

  attr_reader :tempalte, :args, :kwds

  def initialize template, *subs
    @template = template
    @args, @kwds = Cmds.subs_to_args_and_kwds subs
  end #initialize

  def call *subs
    args, kwds = merge_subs subs

    cmd = Cmds.sub @template, args, kwds

    out, err, status = Open3.capture3 cmd

    Cmds::Result.new cmd, status, out, err
  end #call

  # returns a new `Cmds` with the subs merged in
  def curry *subs
    self.class.new @template, *merge_subs(subs)
  end

  private

    def merge_subs subs
      # break `subs` into `args` and `kwds`
      args, kwds = Cmds.subs_to_args_and_kwds subs

      [@args + args, @kwds.merge(kwds)]
    end #merge_subs

  # end private
end # Cmds

# convenience for Cmds::run
def Cmds *args
  Cmds.run *args
end
