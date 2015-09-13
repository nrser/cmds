class Cmds
  # invokes the command and returns a Result with the captured outputs
  def capture *subs, &input_block
    Cmds.debug "calling Cmds#capture:",
      subs: subs,
      input_block: input_block

    # merge any stored args and kwds and replace input if provided
    options = merge_options subs, input_block
    Cmds.debug "merged options:",
      options: options

    # build the command string
    cmd = Cmds.sub @template, options[:args], options[:kwds]
    Cmds.debug "built command string: #{ cmd.inspect }"

    # how we create the subprocess depends on how the input is provided.
    # there are three possibilities:
    # 
    # 1.  no input (`options[:input]` is `nil`).
    # 2.  `String` input.
    # 3.  io-like input.
    # 
    # all of these options could be handled with `Cmds::stream`, and
    # maybe they should be to avoid the confusion of branches, but for
    # the moment and of somewhat historic reasons the first two are handled 
    # using `Open3.capture3`, which (3) must be handled via `Cmds::stream`.
    # 
    out, err, status = if options[:input].nil?
      Cmds.debug "no input present, using capture3."
      Open3.capture3 cmd

    else
      Cmds.debug "input present."

      if options[:input].is_a? String
        Cmds.debug "input is a String, using capture3."
        Open3.capture3 cmd, stdin_data: options[:input]

      else
        Cmds.debug NRSER.squish <<-BLOCK
          input is not a string, so it should be something we can pass
          to spawn.
        BLOCK

        Cmds.debug "creating pipes and threads for output..."

        out_r, out_w = IO.pipe
        err_r, err_w = IO.pipe

        # create threads to read from stdout and stderr
        out_reader, err_reader = [
          ['OUTPUT', out_r],
          ['ERROR', err_r]
        ].map do |name, pipe_r|
          Cmds.debug "creating #{ name } thread..."
          thread = Thread.new do
            Thread.current[:name] = name
            Cmds.debug "thread started, reading...",
              pipe_r: pipe_r
            value = pipe_r.read
            pipe_r.close unless pipe_r.closed?
            Cmds.debug "done."
            value
          end # Thread
          Cmds.debug "#{ name } thread created."
          thread
        end # map

        Cmds.debug "calling Cmds#stream..."
        status = stream do |io|
          # send the input to stream, which sends it to spawn
          io.in = options[:input]
          # and send the write sides of the pipes for output
          io.out = out_w
          io.err = err_w
        end
        Cmds.debug "Cmds#stream completed with status #{ status.inspect }."

        # close child ios (from open3)
        # i guess 'cause the spawn got these write handles we don't need them
        # in this process?
        Cmds.debug "closing write handles for output pipes..."
        [out_w, err_w].map &:close
        Cmds.debug "write handles closed for output pipes."

        # wait for the threads to complete
        Cmds.debug "joining output threads..."
        [out_reader, err_reader].map &:join
        Cmds.debug "output threads completed."

        Cmds.debug "done, returning output values and status."
        [out_reader.value, err_reader.value, status]

      end # if input is a String / else
    end # if input

    # status returned by capture3 is a Process::Status
    status = status.exitstatus if status.respond_to? :exitstatus

    # build a Result
    result = Cmds::Result.new cmd, status, out, err

    # tell the Result to assert if the Cmds has been told to, which will
    # raise a SystemCallError with the exit status if it was non-zero
    result.assert if @assert

    return result
  end # #capture
end