# stdlib
require 'shellwords'
require 'open3'
require 'erubis'

# deps
require 'nrser'

# project
require "cmds/version"

class Cmds
  # subclasses
  # ==========

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

    # raises an error if there was one
    # returns the Result so that it can be chained
    def raise_error
      if error?
        msg = NRSER.squish <<-BLOCK
          command `#{ @cmd }` exited with status #{ @status }
          and stderr output #{ err.inspect }
        BLOCK

        raise SystemCallError.new msg, @status
      end
      self
    end # raise_error
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
  end # end ERBContext

  class IOHandler
    attr_reader :input, :out, :err

    def initialize
      @out = $stdout
      @err = $stderr
      @input = nil
    end

    def input &block
      @input = block
    end

    def out &block
      @out = block
    end

    def out= io
      unless io.is_a? IO
        raise ArgumentError.new NRSER.squish <<-BLOCK
          out must be set to an IO, not #{ io.inspect }
        BLOCK
      end
      @out = io
    end

    def out_line line
      handle_line @out, line
    end

    def err &block
      @err = block
    end

    def err= io
      unless io.is_a? IO
        raise ArgumentError.new NRSER.squish <<-BLOCK
          err must be set to an IO, not #{ io.inspect }
        BLOCK
      end
      @err = io
    end

    def err_line line
      handle_line @err, line
    end

    private

      def handle_line dest, line
        if dest.is_a? Proc
          dest.call line
        else
          dest.puts line
        end
      end

    # end private
  end # end IOHandler

  # class methods
  # =============

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

    context = ERBContext.new(args, kwds)
    erb = ShellEruby.new(replace_shortcuts cmd)

    NRSER.squish erb.result(context.get_binding)
  end # ::sub

  def self.subs_to_args_kwds_input subs
    args = []
    kwds = {}
    input = nil

    case subs.length
    when 0
      # nothing to do
    when 1
      # can either be a hash, which is interpreted as a keywords,
      # or an array, which is interpreted as positional arguments
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

    when 2, 3
      # first arg needs to be an array, second a hash, and optional third
      # can be input
      unless subs[0].is_a? Array
        raise TypeError.new NRSER.squish <<-BLOCK
          first *subs arg needs to be an array, not #{ subs[0].inspect }
        BLOCK
      end

      unless subs[1].is_a? Hash
        raise TypeError.new NRSER.squish <<-BLOCK
          second *subs arg needs to be a Hash, not #{ subs[1].inspect }
        BLOCK
      end

      args, kwds, input = subs
    else
      raise ArgumentError.new NRSER.squish <<-BLOCK
        must provide one or two *subs arguments, received #{ 1 + subs.length }
      BLOCK
    end

    [args, kwds, input]
  end

  # create a new Cmd from template and subs and call it
  def self.run template, *subs
    args, kwds, input = subs_to_args_kwds_input subs
    self.new(template, args: args, kwds: kwds, input: input).call
  end

  def self.ok? template, *subs
    args, kwds, input = subs_to_args_kwds_input subs
    self.new(template, args: args, kwds: kwds, input: input).ok?
  end

  def self.error? template, *subs
    args, kwds, input = subs_to_args_kwds_input subs
    self.new(template, args: args, kwds: kwds, input: input).error?
  end

  def self.raise_on_error template, *subs
    args, kwds, input = subs_to_args_kwds_input subs
    self.new(
      template,
      args: args,
      kwds: kwds,
      input: input,
      raise_on_error: true
    ).call
  end

  def self.replace_shortcuts template
    template
      .gsub(
        # %s => <%= arg %>
        /(\A|[[:space:]])\%s(\Z|[[:space:]])/,
        '\1<%= arg %>\2'
      )
      .gsub(
        # %%s => %s (escpaing)
        /(\A|[[:space:]])(\%+)\%s(\Z|[[:space:]])/,
        '\1\2s\3'
      )
      .gsub(
        # %{key} => <%= key %>, %{key?} => <%= key? %>
        /(\A|[[:space:]])\%\{([a-zA-Z_]+\??)\}(\Z|[[:space:]])/,
        '\1<%= \2 %>\3'
      )
      .gsub(
        # %%{key} => %{key}, %%{key?} => %{key?} (escpaing)
        /(\A|[[:space:]])(\%+)\%\{([a-zA-Z_]+\??)\}(\Z|[[:space:]])/,
        '\1\2{\3}\4'
      )
      .gsub(
        # %<key>s => <%= key %>, %<key?>s => <%= key? %>
        /(\A|[[:space:]])\%\<([a-zA-Z_]+\??)\>s(\Z|[[:space:]])/,
        '\1<%= \2 %>\3'
      )
      .gsub(
        # %%<key>s => %<key>s, %%<key?>s => %<key?>s (escaping)
        /(\A|[[:space:]])(\%+)\%\<([a-zA-Z_]+\??)\>s(\Z|[[:space:]])/,
        '\1\2<\3>s\4'
      )
  end # ::replace_shortcuts

  def self.stream template, *subs, &block
    Cmds.new(template).stream *subs, &block
  end

  def self.stream! template, *subs, &block
    Cmds.new(template, raise_on_error: true).stream *subs, &block
  end # ::stream!

  attr_reader :tempalte, :args, :kwds, :input, :raise_on_error

  def initialize template, opts = {}
    @template = template
    @args = opts[:args] || []
    @kwds = opts[:kwds] || {}
    @input = opts[:input] || nil
    @raise_on_error = opts[:raise_on_error] || false
  end #initialize

  def call *subs
    # merge any stored args and kwds and get any overriding input
    args, kwds, input = merge_subs subs

    cmd = self.cmd *subs

    out, err, status = if input.nil?
      Open3.capture3 cmd
    else
      Open3.capture3 cmd, stdin_data: input
    end

    result = Cmds::Result.new cmd, status.exitstatus, out, err

    result.raise_error if @raise_on_error

    return result
  end #call

  # get the command with values substituted in
  def cmd *subs
    # merge any stored args and kwds and get any overriding input
    args, kwds, input = merge_subs subs
    Cmds.sub @template, args, kwds
  end

  # returns a new `Cmds` with the subs merged in
  def curry *subs
    args, kwds, input = merge_subs(subs)
    self.class.new @template, args: args, kwds: kwds, input: input
  end

  def ok?
    call.ok?
  end

  def error?
    call.error?
  end

  def raise_on_error
    call.raise_error
  end

  # inspired by
  # 
  # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
  # 
  def stream *subs, &block
    handler = IOHandler.new

    if block
      input = block.call handler
      unless input.nil? || handler.input.nil?
        raise ArgumentError.new NRSER.squish <<-BLOCK
          block returned a value considered input and set a handler for
          input; pick one or the other.
        BLOCK
      end
    end

    # see: http://stackoverflow.com/a/1162850/83386
    status = Open3.popen3(cmd *subs) do |stdin, stdout, stderr, thread|
      # read each stream from a new thread
      { :out => stdout, :err => stderr }.each do |key, stream|
        Thread.new do
          until (line = stream.gets).nil? do
            # yield the block depending on the stream
            if key == :out
              handler.out_line line
            else
              handler.err_line line
            end
          end
        end
      end

      thread.join # don't exit until the external process is done

      # this should be the exit status?
      thread.value.exitstatus
    end

    if @raise_on_error && status != 0
      msg = NRSER.squish <<-BLOCK
        streamed command `#{ @cmd }` exited with status #{ status }
      BLOCK

      raise SystemCallError.new msg, status
    end

    return status
  end #stream

  private

    def merge_subs subs
      # break `subs` into `args` and `kwds`
      args, kwds, input = Cmds.subs_to_args_kwds_input subs

      # use any default input if we didn't get a new one
      input = @input if input.nil?

      [@args + args, @kwds.merge(kwds), input]
    end #merge_subs

  # end private
end # Cmds

# convenience for Cmds::run
def Cmds *args
  Cmds.run *args
end

def Cmds? *args
  Cmds.ok? *args
end

def Cmds! *args
  Cmds.raise_on_error *args
end
