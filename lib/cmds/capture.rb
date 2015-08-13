class Cmds
  # invokes the command and returns a Result with the captured outputs
  def capture *subs, &input_block
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
            # i would imagine this happens when the subprocess exits and/or
            # closes stdin?
            Cmds.debug "caught Errno::EPIPE, stopping writing input"
          end
          Cmds.debug "closing stdin"
          stdin.close
          Cmds.debug "done, returning captured outputs and status."
          [out_reader.value, err_reader.value, thread.value]
        }

      end # if input is a String
    end # if input

    # build a Result
    result = Cmds::Result.new cmd, status.exitstatus, out, err

    result.raise_error if @assert

    return result
  end # #capture
end