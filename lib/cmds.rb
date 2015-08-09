# stdlib
require 'shellwords'
require 'open3'
require 'erubis'
require 'thread'
require 'logger'

# deps
require 'nrser'

# project
require "cmds/version"

class Cmds
  # constants
  THREAD_DEBUG_COLORS = {
    'INPUT' => :cyan,
    'OUTPUT' => :green,
    'ERROR' => :red,
  }

  # class variables
  @@logger = nil

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
    attr_accessor :in, :out, :err

    def initialize
      @queue = Queue.new
      @in = nil
      @out = $stdout
      @err = $stderr
    end

    def on_out &block
      @out = block
    end

    # called in seperate thread handling process IO
    def thread_send_out line
      @queue << [:out, line]
    end

    def on_err &block
      @err = block
    end

    # called in seperate thread handling process IO
    def thread_send_err line
      @queue << [:err, line]
    end

    def start
      # if out is a proc, it's not done
      out_done = ! @out.is_a?(Proc)
      # same for err
      err_done = ! @err.is_a?(Proc)

      until out_done && err_done
        key, line = @queue.pop
        
        case key
        when :out
          if line.nil?
            out_done = true
          else
            handle_line @out, line
          end

        when :err
          if line.nil?
            err_done = true
          else
            handle_line @err, line
          end

        else
          raise "bad key: #{ key.inspect }"
        end
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

  def self.configure_logger dest = $stdout
    require 'pastel'
    @@pastel = Pastel.new

    @@logger = Logger.new dest
    @@logger.level = Logger::DEBUG
    @@logger.formatter = proc do |severity, datetime, progname, msg|
      if Thread.current[:name]
        msg = "[Cmds #{ severity } - #{ Thread.current[:name ] }] #{msg}\n"

        if color = Cmds::THREAD_DEBUG_COLORS[Thread.current[:name]]
          msg = @@pastel.method(color).call msg
        end

        msg
      else
        "[Cmds #{ severity }] #{msg}\n"
      end
    end
  end

  # log debug stuff
  def self.debug msg, values = {}
    return unless @@logger
    unless values.empty?
      msg += "\n" + values.map {|k, v| "  #{ k }: #{ v.inspect }" }.join("\n")
    end
    @@logger.debug msg
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
    Cmds.debug "running with",
      input_block: input_block
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
    Cmds.debug "Cmds constructed",
      template: template,
      options: opts

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

    Cmds.debug "built command string: #{ cmd.inspect }"

    # make the call with input if provided
    out, err, status = if options[:input].nil?
      Cmds.debug "no input present, using capture3."
      Open3.capture3 cmd
    else
      Cmds.debug "input present."

      if options[:input].is_a? String
        Cmds.debug "input is a String, using capture3."
        Open3.capture3 cmd, stdin_data: options[:input]

      else
        Cmds.debug "input is not a string, so it should be readable."
        Cmds.debug "need to use threads..."

        # from the capture3 implementation
        Open3.popen3(cmd) {|stdin, stdout, stderr, thread|
          out_reader = Thread.new { stdout.read }
          err_reader = Thread.new { stderr.read }
          begin
            # TODO: this reads all as one chunk, might want to stream
            stdin.write options[:input].read
          rescue Errno::EPIPE
          end
          stdin.close
          [out_reader.value, err_reader.value, thread.value]
        }

      end # if input is a String
    end # if input

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
    # default to the instance variable
    input = @input

    if input_block
      case input_block.arity
      when 0
        # when the input block takes no arguments it returns the input
        input = input_block.call
      when 1
        # when the input block takes one argument, give it the handler and
        # ignore the return value
        input_block.call handler

        # if input was assigned to the handler in the block, use it as input
        input = handler.in unless handler.in.nil?
      else
        # bad block provided
        raise ArgumentError.new NRSER.squish <<-BLOCK
          provided input block must have arity 0 or 1
        BLOCK
      end # case input.arity
    end # if input_block

    # build the command string
    cmd = Cmds.sub @template, options[:args], options[:kwds]

    spawn_opts = {}

    pipe_in = false
    pipe_out = false
    pipe_err = false


    Cmds.debug "looking at input...",
      input: input
    case input
    when nil
      Cmds.debug "input is nil, no spawn opt."
      # pass
    when String
      Cmds.debug "input is a String, creating pipe..."

      pipe_in = true
      in_r, in_w = IO.pipe
      spawn_opts[:in] = in_r

      # don't buffer input
      in_w.sync = true
    else
      Cmds.debug "input should be io-like, setting spawn opt.",
        input: input
      if input == $stdin
        Cmds.debug "input is $stdin."
      end
      spawn_opts[:in] = input
    end

    Cmds.debug "looking at output..."
    if handler.out.is_a? Proc
      Cmds.debug "output is a Proc, creating pipe..."
      pipe_out = true
      out_r, out_w = IO.pipe
      spawn_opts[:out] = out_w
    else
      Cmds.debug "output should be io-like, setting spawn opt.",
        output: handler.out
      if handler.out == $stdout
        Cmds.debug "output is $stdout."
      end
      spawn_opts[:out] = handler.out
    end

    Cmds.debug "looking at error..."
    if handler.err.is_a? Proc
      Cmds.debug "error is a Proc, creating pipe..."
      pipe_err = true
      err_r, err_w = IO.pipe
      spawn_opts[:err] = err_w
    else
      Cmds.debug "output should be io-like, setting spawn opt.",
        error: handler.err
      if handler.err == $stderr
        Cmds.debug "error is $stderr."
      end
      spawn_opts[:err] = handler.err
    end

    Cmds.debug "spawning...",
      cmd: cmd,
      opts: spawn_opts

    pid = spawn cmd, spawn_opts

    Cmds.debug "spawned.",
      pid: pid

    wait_thread = Process.detach pid

    # close child ios if created
    # the spawned process will read from in_r so we don't need it
    in_r.close if pipe_in
    out_w.close if pipe_out
    err_w.close if pipe_err

    # create threads to handle the pipes

    in_thread = if pipe_in
      Thread.new do
        Thread.current[:name] = "INPUT"
        Cmds.debug "thread started, writing input..."

        in_w.write input
        Cmds.debug "write done, closing stdin"
        in_w.close
      end # Thread
    end

    out_thread = if pipe_out
      Thread.new do
        Thread.current[:name] = "OUTPUT"
        Cmds.debug "thread started"

        loop do
          Cmds.debug "blocking on gets..."
          line = out_r.gets
          if line.nil?
            Cmds.debug "received nil, output done."
          else
            Cmds.debug NRSER.squish <<-BLOCK
              received #{ line.bytesize } bytes, passing to handler.
            BLOCK
          end
          handler.thread_send_out line
          break if line.nil?
        end
      end
    end

    err_thread = if pipe_err
      Thread.new do
        Thread.current[:name] = "ERROR"
        Cmds.debug "thread started"

        loop do
          Cmds.debug "blocking on gets..."
          line = err_r.gets
          if line.nil?
            Cmds.debug "received nil, output done."
          else
            Cmds.debug NRSER.squish <<-BLOCK
              received #{ line.bytesize } bytes, passing to handler.
            BLOCK
          end
          handler.thread_send_err line
          break if line.nil?
        end
      end
    end

    Cmds.debug "handing off main thread control to the handler..."
    begin
      handler.start
    ensure
      # i *think* we need to wait for the threads to complete before
      # closing the pipes
      if pipe_in
        Cmds.debug "joining input thread..."
        in_thread.join

        Cmds.debug "closing pipe..."
        in_w.close unless in_w.closed?
      end

      if pipe_out
        Cmds.debug "joining output thread..."
        out_thread.join

        Cmds.debug "closing output pipe..."
        out_r.close unless out_r.closed?
      end

      if pipe_err
        Cmds.debug "joining error thread..."
        err_thread.join

        Cmds.debug "closing error pipe..."
        err_r.close unless err_r.closed?
      end

      # then we need to make sure we wait for the process to complete
      Cmds.debug "joining wait thread"
      wait_thread.join
    end

    Cmds.debug "getting exit status..."
    status = wait_thread.value.exitstatus
    Cmds.debug "exit status: #{ status.inspect }"

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
def Cmds *args, &block
  Cmds.run *args, &block
end

def Cmds? *args, &block
  Cmds.ok? *args, &block
end

def Cmds! *args, &block
  Cmds.assert *args, &block
end
