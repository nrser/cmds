# deps
require 'nrser'

# project
require 'cmds/debug'
require 'cmds/util'
require 'cmds/spawn'
require 'cmds/erb_context'
require 'cmds/shell_eruby'
require 'cmds/result'

module Cmds
  # a command consisting of a template, base/common parameters and input,
  # and options.
  # 
  class Cmd
    # ERB stirng template (with Cmds-specific extensions) for the command.
    # 
    # @return [String]
    attr_reader :template
    
    # base/common positional parameters to render into the command
    # template.
    # 
    # defaults to `[]`.
    # 
    # {#prepare} and the methods that invoke it (like {#capture}, 
    # {#stream}, etc.) accept `*args`, which will be appended to
    # these values to create the final array for rendering.   
    # 
    # @return [Array<Object>]   
    attr_reader :args
    
    # base/common keyword parameters to render into the command template.
    # 
    # defaults to `{}`.
    # 
    # {#prepare} and the methods that invoke it (like {#capture}, 
    # {#stream}, etc.) accept `**kwds`, which will be merged on top of
    # these values to create the final hash for rendering.
    # 
    # @return [Hash{Symbol => Object}]
    attr_reader :kwds
    
    # string or readable IO-like object to use as default input to the
    # command.
    # 
    # {#prepare} and the methods that invoke it (like {#capture}, 
    # {#stream}, etc.) accept an optional block that will override this
    # value if present.
    # 
    # @return [String | #read]
    attr_reader :input
    
    # if `true`, will execution will raise an error on non-zero exit code.
    # 
    # defaults to `false`.
    # 
    # @return [Boolean]
    attr_reader :assert
    
    # environment variables to set for command execution.
    # 
    # defaults to `{}`.
    # 
    # @return [Hash{String | Symbol => String}]
    attr_reader :env
    
    # format specifier symbol:
    # 
    # -   `:squish`
    #     -   collapse rendered command string to one line.
    # -   `:pretty`
    #     -   clean up and backslash suffix line endings.
    # 
    # defaults to `:squish`.
    # 
    # @return [:squish | :pretty]
    attr_reader :format
    
    
    # directory to run the command in.
    # 
    # @return [nil | String]
    attr_reader :chdir
    
    
    # construct a Cmd.
    # 
    # @param [String] template
    #   sets the {#template} attribute.
    # 
    # @param [Hash] opts
    # 
    # @option opts [Array<Object>] :args
    #   sets the {#args} attribute.
    # 
    # @option opts [Hash{Symbol => Object}] :kwds
    #   sets the {#kwds} attribute.
    # 
    # @option opts [String | #read] :input
    #   sets the {#input} attribute.
    # 
    # @option opts [Hash{Symbol => String}] :env
    #   sets the {#env} attribute.
    # 
    # @option opts [:squish, :pretty] :format
    #   sets the {#format} attribute.
    # 
    # @option opts [nil | String] :chdir
    #   sets the {#chdir} attribute.
    # 
    def initialize template, **opts
      Cmds.debug "Cmd constructing...",
        template: template,
        opts: opts

      @template = template
      @args = opts[:args] || []
      @kwds = opts[:kwds] || {}
      @input = opts[:input] || nil
      @assert = opts[:assert] || false
      @env = opts[:env] || {}
      @format = opts[:format] || :squish
      @env_mode = opts[:env_mode] || :inline
      @chdir = opts[:chdir] || nil
    end # #initialize
    
    
    # returns a new {Cmd} with the parameters and input merged in
    def curry *args, **kwds, &input_block
      self.class.new @template, {
        args: (@args + args),
        kwds: (@kwds.merge kwds),
        input: (input ? input.call : @input),
        assert: @assert,
        env: @env,
        format: @format,
        chdir: @chdir,
      }
    end
    
    
    # render parameters into `@template`.
    # 
    # @note the returned string is **not** formatted for shell execution.
    #       Cmds passes this string through {Cmds.format} before execution,
    #       which addresses newlines in the rendered string through "squishing"
    #       everything down to one line or adding `\` to line ends.
    # 
    # @param args (see #capture)
    # @param kwds (see #capture)
    # 
    # @return [String]
    #   the rendered command string.
    # 
    def render *args, **kwds
      context = Cmds::ERBContext.new((@args + args), @kwds.merge(kwds))
      erb = Cmds::ShellEruby.new Cmds.replace_shortcuts(@template)
      rendered = NRSER.dedent erb.result(context.get_binding)
      
      if @env_mode == :inline && !@env.empty?
        rendered = @env.sort_by {|name, value|
          name
        }.map {|name, value|
          "#{ name }=#{ Cmds.esc value }"
        }.join("\n\n") + "\n\n" + rendered
      end
      
      rendered
    end
    
    
    # prepare a shell-safe command string for execution.
    # 
    # @param args (see #capture)
    # @param kwds (see #capture)
    # 
    # @return [String]
    #   the prepared command string.
    # 
    def prepare *args, **kwds
      Cmds.format render(*args, **kwds), @format
    end # #prepare
    
    
    def stream *args, **kwds, &io_block
      Cmds.debug "entering Cmd#stream",
        args: args,
        kwds: kwds,
        io_block: io_block
      
      Cmds.spawn  prepare(*args, **kwds),
                  input: @input,
                  # include env if mode is spawn argument
                  env: (@env_mode == :spawn_arg ? @env : {}),
                  chdir: @chdir,
                  &io_block
    end # #stream
    
    
    # executes the command and returns a {Cmds::Result} with the captured
    # outputs.
    # 
    # @param [Array<Object>] args
    #   positional parameters to append to those in `@args` for rendering 
    #   into the command string.
    # 
    # @param [Hash{Symbol => Object}] kwds
    #   keyword parameters that override those in `@kwds` for rendering
    #   into the command string.
    # 
    # @param [#call] input_block
    #   optional block that returns a string or readable object to override
    #   `@input`.
    # 
    # @return [Cmds::Result]
    #   result of execution with command string, status, stdout and stderr.
    # 
    def capture *args, **kwds, &input_block
      Cmds.debug "entering Cmds#capture",
        args: args,
        kwds: kwds,
        input: input
      
      # prepare the command string
      cmd = prepare *args, **kwds
      
      # extract input from block via `call` if one is provided,
      # otherwise default to instance variable (which may be `nil`)
      input = input_block.nil? ? @input : input_block.call
      
      Cmds.debug "prepared",
        cmd: cmd,
        input: input
      
      # strings output will be concatenated onto
      out = ''
      err = ''

      Cmds.debug "calling Cmds.spawn..."
      
      status = Cmds.spawn(
        cmd,
        # include env if mode is spawn argument
        env: (@env_mode == :spawn_arg ? @env : {}),
        chdir: @chdir
      ) do |io|
        # send the input to stream, which sends it to spawn
        io.in = input

        # and concat the output lines as they come in
        io.on_out do |line|
          out += line
        end

        io.on_err do |line|
          err += line
        end
      end
      
      Cmds.debug "Cmds.spawn completed",
        status: status

      # build a Result
      # result = Cmds::Result.new cmd, status, out_reader.value, err_reader.value
      result = Cmds::Result.new cmd, status, out, err

      # tell the Result to assert if the Cmds has been told to, which will
      # raise a SystemCallError with the exit status if it was non-zero
      result.assert if @assert

      return result
    end # #capture
    
    
    alias_method :call, :capture
    
    
    # execute command and return `true` if it exited successfully.
    # 
    # @param *args (see #capture)
    # @param **kwds (see #capture)
    # @param &input_block (see #capture)
    # 
    # @return [Boolean]
    #   `true` if exit code was `0`.
    # 
    def ok? *args, **kwds, &io_block
      stream(*args, **kwds, &io_block) == 0
    end
    
    
    # execute command and return `true` if it failed.
    # 
    # @param *args (see #capture)
    # @param **kwds (see #capture)
    # @param &input_block (see #capture)
    # 
    # @return [Boolean]
    #   `true` if exit code was not `0`.
    # 
    def error? *args, **kwds, &io_block
      stream(*args, **kwds, &io_block) != 0
    end
    
    
    # def assert
    #   capture.raise_error
    # end
    
    
    def proxy
      stream do |io|
        io.in = $stdin
      end
    end
    
    
    # captures and returns stdout
    # (sugar for `#capture(*args, **kwds, &input_block).out`).
    #
    # @see #capture
    # @see Result#out
    #
    # @param *args (see #capture)
    # @param **kwds (see #capture)
    # @param &input_block (see #capture)
    #
    # @return [String]
    #   the command's stdout.
    #
    def out *args, **kwds, &input_block
      capture(*args, **kwds, &input_block).out
    end
    
    
    # captures and returns stdout
    # (sugar for `#capture(*args, **kwds, &input_block).out`).
    #
    # @see #capture
    # @see Result#out
    #
    # @param args [Array] see {.capture}.
    # @param kwds [Proc] see {.capture}.
    #
    # @return [String] the command's stdout.
    #
    # @raise [SystemCallError] if the command fails (non-zero exit status).
    #
    def out! *args, **kwds, &input
      capture(*args, **kwds, &input).assert.out
    end
    
    
    # captures and chomps stdout
    # (sugar for `#out(*subs, &input_block).chomp`).
    #
    # @see #out
    #
    # @param *args (see #capture)
    # @param **kwds (see #capture)
    # @param &input_block (see #capture)
    #
    # @return [String]
    #   the command's chomped stdout.
    #
    def chomp *args, **kwds, &input_block
      out(*args, **kwds, &input_block).chomp
    end
    
    
    # captures and chomps stdout, raising an error if the command failed.
    # (sugar for `#out!(*subs, &input_block).chomp`).
    #
    # @see #capture
    # @see Result#out
    #
    # @param *args (see #capture)
    # @param **kwds (see #capture)
    # @param &input_block (see #capture)
    #
    # @return [String]
    #   the command's chomped stdout.
    #
    # @raise [SystemCallError]
    #   if the command fails (non-zero exit status).
    #
    def chomp! *args, **kwds, &input
      out!(*args, **kwds, &input).chomp
    end
    
    
    # captures and returns stdout
    # (sugar for `#capture(*subs, &input_block).err`).
    #
    # @param *args (see #capture)
    # @param **kwds (see #capture)
    # @param &input_block (see #capture)
    # 
    # @see #capture
    # @see Result#err
    #
    # @return [String]
    #   the command's stderr.
    #
    def err *args, **kwds, &input_block
      capture(*args, **kwds, &input_block).err
    end
  end # Cmd
end # Cmds