##
# Handle the actual spawning of child processes via {Process.spawn}
# 
# These methods are the low-level core of the library. Everything ends up here
# to actually execute a command, but users should not need to call them
# directly in most cases.
##

# Requirements
# =======================================================================

# Stdlib
# -----------------------------------------------------------------------
require 'open3'
require 'thread'

# Deps
# -----------------------------------------------------------------------
require 'nrser'

# Project / Package
# -----------------------------------------------------------------------
require 'cmds/pipe'
require 'cmds/io_handler'


# Refinements
# =======================================================================

using NRSER


# Definitions
# =======================================================================

class Cmds
  # @!group Spawn Methods
  
  # Low-level static method to spawn and stream inputs and/or outputs using
  # threads.
  # 
  # This is the core execution functionality of the whole library - everything
  # ends up here.
  # 
  # **_WARNING - This method runs the `cmd` string AS IS - no escaping,
  # formatting, interpolation, etc. are done at this point._**
  # 
  # The whole rest of the library is built on top of this method to provide
  # that stuff, and if you're using this library, you probably want to use that
  # stuff.
  # 
  # You should not need to use this method directly unless you are extending
  # the library's functionality.
  # 
  # Originally inspired by
  # 
  # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
  # 
  # with major modifications from looking at Ruby's [open3][] module.
  # 
  # [open3]: https://ruby-doc.org/stdlib/libdoc/open3/rdoc/Open3.html
  # 
  # At the end of the day ends up calling `Process.spawn`.
  # 
  # @param [String] cmd
  #   **SHELL-READY** command string. This is important - whatever you feed in
  #   here will be run **AS IS** - no escaping, formatting, etc.
  # 
  # @param [Hash{(Symbol | String) => Object}] env
  #   Hash of `ENV` vars to provide for the command.
  #   
  #   We convert symbol keys to strings, but other than that just pass it
  #   through to `Process.spawn`, which I think will `#to_s` everything.
  #   
  #   Pretty much you want to have everything be strings or symbols for this
  #   to make any sense but we're not checking shit at the moment.
  #   
  #   If the {Cmds#env_mode} is `:inline` it should have already prefixed
  #   `cmd` with the definitions and not provide this keyword (or provide
  #   `{}`).
  # 
  # @param [nil | String | #read] input
  #   String or readable input, or `nil` (meaning no input).
  #   
  #   Allows {Cmds} instances can pass their `@input` instance variable.
  #   
  #   Don't provide input here and via `io_block`.
  # 
  # @param [Hash<Symbol, Object>] **spawn_opts
  #   Any additional options are passed as the [options][Process.spawn options]
  #   to {Process.spawn}
  #   
  #   [Process.spawn options]: http://ruby-doc.org/core/Process.html#method-c-spawn
  # 
  # @param [#call & (#arity ∈ {0, 1})] &io_block
  #   Optional block to handle io. Behavior depends on arity:
  #   
  #   -   Arity `0`
  #       -   Block is called and expected to return an object
  #           suitable for input (`nil`, `String` or `IO`-like).
  #   -   Arity `1`
  #       -   Block is called with the {Cmds::IOHandler} instance for the
  #           execution, which it can use to handle input and outputs.
  #   
  #   Don't provide input here and via `input` keyword arg.
  # 
  # @return [Fixnum]
  #   Command exit status.
  # 
  # @raise [ArgumentError]
  #   If `&io_block` has arity greater than 1.
  # 
  # @raise [ArgumentError]
  #   If input is provided via the `input` keyword arg and the `io_block`.
  # 
  def self.spawn  cmd,
                  env: {},
                  input: nil,
                  **spawn_opts,
                  &io_block
    logger.trace "entering Cmds#spawn",
      cmd: cmd,
      env: env,
      input: input,
      spawn_opts: spawn_opts,
      io_block: io_block
    
    # Process.spawn doesn't like a `nil` chdir
    if spawn_opts.key?( :chdir ) && spawn_opts[:chdir].nil?
      spawn_opts.delete :chdir
    end
    
    # create the handler that will be yielded to the input block
    handler = Cmds::IOHandler.new

    # handle input
    # 
    # if a block was provided it overrides the `input` argument.
    # 
    if io_block
      case io_block.arity
      when 0
        # when the input block takes no arguments it returns the input
        
        # Check that `:input` kwd wasn't provided.
        unless input.nil?
          raise ArgumentError,
            "Don't call Cmds.spawn with `:input` keyword arg and a block"
        end
        
        input = io_block.call
        
      when 1
        # when the input block takes one argument, give it the handler and
        # ignore the return value
        io_block.call handler

        # if input was assigned to the handler in the block, use it as input
        unless handler.in.nil?
          
          # Check that `:input` kwd wasn't provided.
          unless input.nil?
            raise ArgumentError,
              "Don't call Cmds.spawn with `:input` keyword arg and a block"
          end
          
          input = handler.in
        end
        
      else
        # bad block provided
        raise ArgumentError.new NRSER.squish <<-BLOCK
          provided input block must have arity 0 or 1
        BLOCK
      end # case io_block.arity
    end # if io_block

    logger.trace "looking at input...",
      input: input

    # (possibly) create the input pipe... this will be nil if the provided
    # input is io-like. in this case it will be used directly in the
    # `spawn` options.
    in_pipe = case input
    when nil, String
      logger.trace "input is a String or nil, creating pipe..."

      in_pipe = Cmds::Pipe.new "INPUT", :in
      spawn_opts[:in] = in_pipe.r

      # don't buffer input
      in_pipe.w.sync = true
      in_pipe

    else
      logger.trace "input should be io-like, setting spawn opt.",
        input: input
      if input == $stdin
        logger.trace "input is $stdin."
      end
      spawn_opts[:in] = input
      nil

    end # case input

    # (possibly) create the output pipes.
    # 
    # `stream` can be told to send it's output to either:
    # 
    # 1.  a Proc that will invoked with each line.
    # 2.  an io-like object that can be provided as `spawn`'s `:out` or
    #     `:err` options.
    # 
    # in case (1) a `Cmds::Pipe` wrapping read and write piped `IO` instances
    # will be created and assigned to the relevant of `out_pipe` or `err_pipe`.
    # 
    # in case (2) the io-like object will be sent directly to `spawn` and
    # the relevant `out_pipe` or `err_pipe` will be `nil`.
    #
    out_pipe, err_pipe = [
      ["ERROR", :err],
      ["OUTPUT", :out],
    ].map do |name, sym|
      logger.trace "looking at #{ name }..."
      
      dest = handler.public_send sym
      
      # see if hanlder.out or hanlder.err is a Proc
      if dest.is_a? Proc
        logger.trace "#{ name } is a Proc, creating pipe..."
        pipe = Cmds::Pipe.new name, sym
        # the corresponding :out or :err option for spawn needs to be
        # the pipe's write handle
        spawn_opts[sym] = pipe.w
        # return the pipe
        pipe

      else
        logger.trace "#{ name } should be io-like, setting spawn opt.",
          output: dest
        spawn_opts[sym] = dest
        # the pipe is nil!
        nil
      end
    end # map outputs

    logger.trace "spawning...",
      env: env,
      cmd: cmd,
      opts: spawn_opts

    pid = Process.spawn env.map {|k, v| [k.to_s, v]}.to_h,
                        cmd,
                        spawn_opts

    logger.trace "spawned.",
      pid: pid

    wait_thread = Process.detach pid
    wait_thread[:name] = "WAIT"

    logger.trace "wait thread created.",
      thread: wait_thread

    # close child ios if created
    # the spawned process will read from in_pipe.r so we don't need it
    in_pipe.r.close if in_pipe
    # and we don't need to write to the output pipes, that will also happen
    # in the spawned process
    [out_pipe, err_pipe].each {|pipe| pipe.w.close if pipe}

    # create threads to handle any pipes that were created

    in_thread = if in_pipe
      Thread.new do
        Thread.current[:name] = in_pipe.name
        logger.trace "thread started, writing input..."

        in_pipe.w.write input unless input.nil?

        logger.trace "write done, closing in_pipe.w..."
        in_pipe.w.close

        logger.trace "thread done."
      end # Thread
    end

    out_thread, err_thread = [out_pipe, err_pipe].map do |pipe|
      if pipe
        Thread.new do
          Thread.current[:name] = pipe.name
          logger.trace "thread started"

          loop do
            logger.trace "blocking on gets..."
            line = pipe.r.gets
            if line.nil?
              logger.trace "received nil, output done."
            else
              logger.trace \
                "received #{ line.bytesize } bytes, passing to handler."
            end
            handler.thread_send_line pipe.sym, line
            break if line.nil?
          end

          logger.trace \
            "reading done, closing pipe.r (unless already closed)..."
          pipe.r.close unless pipe.r.closed?

          logger.trace "thread done."
        end # thread
      end # if pipe
    end # map threads

    logger.trace "handing off main thread control to the handler..."
    begin
      handler.start

      logger.trace "handler done."

    ensure
      # wait for the threads to complete
      logger.trace "joining threads..."

      [in_thread, out_thread, err_thread, wait_thread].each do |thread|
        if thread
          logger.trace "joining #{ thread[:name] } thread..."
          thread.join
        end
      end

      logger.trace "all threads done."
    end

    status = wait_thread.value.exitstatus
    logger.trace "exit status: #{ status.inspect }"

    logger.trace "checking @assert and exit status..."
    if @assert && status != 0
      # we don't necessarily have the err output, so we can't include it
      # in the error message
      msg = NRSER.squish <<-BLOCK
        streamed command `#{ cmd }` exited with status #{ status }
      BLOCK

      raise SystemCallError.new msg, status
    end

    logger.trace "streaming completed."

    return status
  end # .spawn
  
  
  protected
  # ========================================================================
    
    # Internal method that simply passes through to {Cmds.spawn}, serving as
    # a hook point for subclasses.
    # 
    # Accepts and returns the same things as {Cmds#stream}.
    # 
    # @param (see Cmds#stream)
    # @return (see Cmds#stream)
    # 
    def spawn *args, **kwds, &io_block
      Cmds.spawn  prepare(*args, **kwds),
                  input: input,
                  # include env if mode is spawn argument
                  env: (env_mode == :spawn_arg ? env : {}),
                  chdir: chdir,
                  unsetenv_others: !!@unsetenv_others,
                  &io_block
    end # #spawn
    
  # end protected
  
  
end # Cmds
