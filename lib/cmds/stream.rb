class Cmds
  # stream inputs and/or outputs
  # 
  # originally inspired by
  # 
  # https://nickcharlton.net/posts/ruby-subprocesses-with-stdout-stderr-streams.html
  # 
  # with major modifications from looking at Ruby's open3 module.
  #
  def stream *subs, &input_block
    # use `merge_options` to get the args and kwds (we will take custom
    # care of input below)
    options = merge_options subs, nil

    # create the handler that will be yielded to the input block
    handler = IOHandler.new

    # handle input
    
    # default to the instance variable
    input = @input

    # if a block was provided, it might provide overriding input
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

    # hash of options that will be passed to `spawn`
    spawn_opts = {}

    # flags that are set to true below if pipes are created
    # for in, out and err
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

    Cmds.debug "wait thread created.",
      thread: wait_thread

    # close child ios if created
    # the spawned process will read from in_r so we don't need it
    in_r.close if pipe_in
    # and we don't need to write to the output pipes
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
        streamed command `#{ cmd }` exited with status #{ status }
      BLOCK

      raise SystemCallError.new msg, status
    end

    return status
  end #stream

  # returns a new `Cmds` with the subs merged in
  def curry *subs, &input_block
    self.class.new @template, merge_options(subs, input_block)
  end
end