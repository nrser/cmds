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

    Cmds.debug "looking at input...",
      input: input

    # (possibly) create the input pipe... this will be nil in the cases:
    # 
    # 1.  no input was provided
    # 2.  the provided input is io-like. in this case it will be used directly
    #     in the `spawn` options.
    # 
    in_pipe = case input
    when nil
      Cmds.debug "input is nil, no spawn opt."
      nil

    when String
      Cmds.debug "input is a String, creating pipe..."

      in_pipe = Cmds::Pipe.new "INPUT", :in
      spawn_opts[:in] = in_pipe.r

      # don't buffer input
      in_pipe.w.sync = true
      in_pipe

    else
      Cmds.debug "input should be io-like, setting spawn opt.",
        input: input
      if input == $stdin
        Cmds.debug "input is $stdin."
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
      Cmds.debug "looking at #{ name }..."
      # see if hanlder.out or hanlder.err is a Proc
      if handler.send(sym).is_a? Proc
        Cmds.debug "#{ name } is a Proc, creating pipe..."
        pipe = Cmds::Pipe.new name, sym
        # the corresponding :out or :err option for spawn needs to be
        # the pipe's write handle
        spawn_opts[sym] = pipe.w
        # return the pipe
        pipe

      else
        Cmds.debug "#{ name } should be io-like, setting spawn opt.",
          output: handler.send(sym)
        spawn_opts[sym] = handler.send(sym)
        # the pipe is nil!
        nil
      end
    end # map outputs

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
    # the spawned process will read from in_pipe.r so we don't need it
    in_pipe.r.close if in_pipe
    # and we don't need to write to the output pipes, that will also happen
    # in the spawned process
    [out_pipe, err_pipe].each {|pipe| pipe.w.close if pipe}

    # create threads to handle any pipes that were created

    in_thread = if in_pipe
      Thread.new do
        Thread.current[:name] = in_pipe.name
        Cmds.debug "thread started, writing input..."

        in_pipe.w.write input

        Cmds.debug "write done, closing in_pipe.w..."
        in_pipe.w.close

        Cmds.debug "thread done."
      end # Thread
    end

    out_thread, err_thread = [out_pipe, err_pipe].map do |pipe|
      if pipe
        Thread.new do
          Thread.current[:name] = pipe.name
          Cmds.debug "thread started"

          loop do
            Cmds.debug "blocking on gets..."
            line = pipe.r.gets
            if line.nil?
              Cmds.debug "received nil, output done."
            else
              Cmds.debug NRSER.squish <<-BLOCK
                received #{ line.bytesize } bytes, passing to handler.
              BLOCK
            end
            handler.thread_send_line pipe.sym, line
            break if line.nil?
          end

          Cmds.debug "reading done, closing pipe.r (unless already closed)..."
          pipe.r.close unless pipe.r.closed?

          Cmds.debug "thread done."
        end # thread
      end # if pipe
    end # map threads

    Cmds.debug "handing off main thread control to the handler..."
    begin
      handler.start

      Cmds.debug "handler done."

    ensure
      # wait for the threads to complete
      Cmds.debug "joining threads..."

      [in_thread, out_thread, err_thread, wait_thread].each do |thread|
        thread.join if thread
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

    return status
  end #stream
end