# stdlib
require 'shellwords'
require 'open3'
require 'erubis'
require 'thread'

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
      @queue = Queue.new

      @out = $stdout
      @out_closed = false

      @err = $stderr
      @err_closed = false

      @input = nil
    end

    def on_in &block
      @input = block
    end

    def on_out &block
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

    # called in seperate thread handling process IO
    def send_out line
      @queue << [:out, line]
    end

    def on_err &block
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

    # called in seperate thread handling process IO
    def send_err line
      @queue << [:err, line]
    end

    def start
      loop do
        key, line = @queue.pop
        
        case key
        when :out
          if line.nil?
            @out_closed = true
          else
            handle_line @out, line
          end

        when :err
          if line.nil?
            @err_closed = true
          else
            handle_line @err, line
          end

        else
          raise "bad key: #{ key.inspect }"
        end

        break if @out_closed && @err_closed
      end
    end #start

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

  def self.options subs, input_block
    args = []
    kwds = {}
    input = input_block.nil? ? nil : input_block.call

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

    when 2
      # first arg needs to be an array, second a hash
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

      args, kwds = subs
    else
      raise ArgumentError.new NRSER.squish <<-BLOCK
        must provide one or two *subs arguments, received #{ 1 + subs.length }
      BLOCK
    end

    return {
      args: args,
      kwds: kwds,
      input: input,
    }
  end

  # create a new Cmd from template and subs and call it
  def self.run template, *subs, &input_block
    new(template, options(subs, input_block)).call
  end

  def self.ok? template, *subs, &input_block
    new(template, options(subs, input_block)).ok?
  end

  def self.error? template, *subs, &input_block
    new(template, options(subs, input_block)).error?
  end

  def self.assert template, *subs, &input_block
    new(
      template,
      options(subs, input_block).merge!(assert: true)
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

  def self.stream template, *subs, &input_block
    Cmds.new(template).stream *subs, &input_block
  end

  def self.stream! template, *subs, &input_block
    Cmds.new(template, assert: true).stream *subs, &input_block
  end # ::stream!

  attr_reader :tempalte, :args, :kwds, :input, :assert

  def initialize template, opts = {}
    @template = template
    @args = opts[:args] || []
    @kwds = opts[:kwds] || {}
    @input = opts[:input] || nil
    @assert = opts[:assert] || false
  end #initialize

  # invokes the command and returns a Result
  def call *subs, &input_block
    # merge any stored args and kwds and replace input if provided
    options = merge_options subs, input_block

    # build the command string
    cmd = Cmds.sub @template, options[:args], options[:kwds]

    # make the call with input if provided
    out, err, status = if options[:input].nil?
      Open3.capture3 cmd
    else
      Open3.capture3 cmd, stdin_data: options[:input]
    end

    # build a Result
    result = Cmds::Result.new cmd, status.exitstatus, out, err

    result.raise_error if @assert

    return result
  end #call

  # inspired by
  # 
  # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
  # 
  def stream *subs, &input_block
    # use `merge_options` to get the args and kwds (we will take custom
    # care of input below)
    options = merge_options subs, nil

    # create the handler that will be yielded to the input block
    handler = IOHandler.new

    # handle input
    # 
    # 
    if input_block
      input = input_block.call handler
      unless input.nil? || handler.input.nil?
        raise ArgumentError.new NRSER.squish <<-BLOCK
          block returned a value considered input and set a handler for
          input; pick one or the other.
        BLOCK
      end
    end

    # build the command string
    cmd = Cmds.sub @template, options[:args], options[:kwds]

    # see: http://stackoverflow.com/a/1162850/83386
    status = Open3.popen3(cmd) do |stdin, stdout, stderr, thread|
      # read each stream from a new thread
      {
        stdout => handler.method(:send_out),
        stderr => handler.method(:send_err),
      }.each do |stream, meth|
        Thread.new do
          loop do
            line = stream.gets
            meth.call line
            break if line.nil?
          end
        end # Thread
      end

      # start the handler
      handler.start

      thread.join # don't exit until the external process is done

      # this should be the exit status?
      thread.value.exitstatus
    end

    if @assert && status != 0
      msg = NRSER.squish <<-BLOCK
        streamed command `#{ @cmd }` exited with status #{ status }
      BLOCK

      raise SystemCallError.new msg, status
    end

    return status
  end #stream

  # returns a new `Cmds` with the subs merged in
  def curry *subs, &input_block
    self.class.new @template, merge_options(subs, input_block)
  end

  def ok?
    call.ok?
  end

  def error?
    call.error?
  end

  def assert
    call.raise_error
  end

  private

    # merges options already present on the object with options
    # provided via subs and input_block and returns a new options
    # Hash
    def merge_options subs, input_block
      # get the options present in the arguments
      options = Cmds.options subs, input_block
      # the new args are created by appending the provided args to the
      # existing ones
      options[:args] = @args + options[:args]
      # the new kwds are created by merging the provided kwds into the
      # exising ones (new values override previous)
      options[:kwds] = @kwds.merge options[:kwds]
      # if there is input present via the provided block, it is used.
      # otherwise, previous input is used, which may be `nil`
      options[:input] ||= @input
      return options
    end

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
  Cmds.assert *args
end
