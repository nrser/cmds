# stdlib
require 'thread'
require 'pty'

# deps
require 'nrser'
require 'nrser/refinements'

# project
require 'cmds/pipe'
require 'cmds/io_handler'

class Cmds
  # internal core function to spawn and stream inputs and/or outputs using
  # threads.
  # 
  # originally inspired by
  # 
  # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
  # 
  # with major modifications from looking at Ruby's open3 module.
  # 
  # @param [String] cmd
  #   shell-ready command string.
  # 
  # @param [nil | String | #read] input
  #   string or readable input. here so that Cmds instances can pass their
  #   `@input` instance variable -- `&io_block` overrides it.
  # 
  # @param [Hash{Symbol | String => Object}] env
  #   blah
  # 
  # @param [#call & (#arity ∈ {0, 1})] &io_block
  #   optional block to handle io. behavior depends on arity:
  #   
  #   -   arity `0`
  #       -   block is called and expected to return an object
  #           suitable for input (`nil`, `String` or `IO`-like).
  #   -   arity `1`
  #       -   block is called with the {Cmds::IOHandler} instance for the
  #           execution, which it can use to handle input and outputs.
  # 
  # @return [Fixnum]
  #   command exit status.
  # 
  # @raise [ArgumentError]
  #   if `&io_block` has arity greater than 1.
  # 
  def self.interact cmd, **opts, &io_block
    raise NotImplementedError, "DOES NOT WORK AT ALL!!!"
    
    Cmds.debug "entering Cmds.interact",
      cmd: cmd,
      opts: opts,
      io_block: io_block
    
    chdir = opts[:chdir]
    pty = opts[:pty] || false
    
    # chdir if provided
    if chdir
      prev_dir = Dir.getwd
      Dir.chdir chdir
    end

    # Used to handle output
    handler = Cmds::IOHandler.new

    Cmds.debug "spawning PTY...",
      cmd: cmd
    
    pty_r, pty_w, pty_pid = PTY.spawn cmd
    
    Cmds.debug "PTY spawned.",
      pid: pty_pid
    
    # Pipe input from $stdin to the PTY read stream
    in_pipe = Cmds::Pipe.new :pty_in, :in
    # Read from this process' $stdin
    in_pipe.r = $stdin
    # Write to the read stream for the PTY
    in_pipe.w = pty_r
    
    
    # Pipe output through block to $stdout
    io_handler = IOHandler.new
    io_handler.on_out &io_block if io_block
    
    out_pipe = Cmds::Pipe.new :pty_out, :out
    # Write to pipe from PTY's read stream
    out_pipe.w = pty_r
    

    wait_thread = Process.detach pid
    wait_thread[:name] = "WAIT"

    Cmds.debug "wait thread created.",
      thread: wait_thread

    # create threads to handle any pipes that were created
    
    in_thread = Thread.new do
      Thread.current[:name] = in_pipe.name
      Cmds.debug "thread started"
      
      loop do
        Cmds.debug "blocking on getc..."
        
        input = $stdin.getc
        
        break if input.nil?
        
        in_pipe.w.write input
      end
      
      Cmds.debug "writing done, closing in_pipe (unless already closed)..."
      in_pipe.r.close unless in_pipe.r.closed?
      in_pipe.w.close unless in_pipe.w.closed?
      
      Cmds.debug "thread done."
    end

    out_thread = Thread.new do
      Thread.current[:name] = out_pipe.name
      Cmds.debug "thread started"

      loop do
        Cmds.debug "blocking on gets..."
        line = out_pipe.r.gets
        if line.nil?
          Cmds.debug "received nil, output done."
        else
          Cmds.debug NRSER.squish <<-BLOCK
            received #{ line.bytesize } bytes, passing to handler.
          BLOCK
        end
        handler.thread_send_line out_pipe.sym, line
        break if line.nil?
      end

      Cmds.debug "reading done, closing out_pipe.r (unless already closed)..."
      out_pipe.r.close unless out_pipe.r.closed?
      out_pipe.w.close unless out_pipe.w.closed?

      Cmds.debug "thread done."
    end # thread


    Cmds.debug "handing off main thread control to the handler..."
    begin
      handler.start

      Cmds.debug "handler done."

    ensure
      # wait for the threads to complete
      Cmds.debug "joining threads..."

      [in_thread, out_thread, wait_thread].each do |thread|
        if thread
          Cmds.debug "joining #{ thread[:name] } thread..."
          thread.join
        end
      end

      Cmds.debug "all threads done."
    end

    status = wait_thread.value.exitstatus
    Cmds.debug "exit status: #{ status.inspect }"

    Cmds.debug "checking @assert and exit status..."
    if @assert && status != 0
      # we don't necessarily have the err output, so we can't include it
      # in the error message
      msg = NRSER.squish <<-BLOCK
        streamed command `#{ cmd }` exited with status #{ status }
      BLOCK

      raise SystemCallError.new msg, status
    end

    Cmds.debug "streaming completed."
    
    if chdir
      Cmds.debug "exiting directory.", dir: chdir
      Dir.chdir prev_dir 
    end
    
    return status
  end # .spawn
  
  

  # Internal method that simply passes through to {Cmds.spawn}, serving as 
  # a hook point for subclasses.
  # 
  # Accepts and returns the same things as 
  # 
  def interact *args, **kwds, &io_block
    Cmds.interact prepare( *args, **kwds ),
                  chdir: chdir,
                  &io_block
  end # #interact
  
  
end # Cmds