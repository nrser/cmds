class Cmds
  # invokes the command and returns a Result with the captured outputs
  def capture *subs, &input_block
    Cmds.debug "entering Cmds#capture",
      subs: subs,
      input_block: input_block

    # merge any stored args and kwds and replace input if provided
    options = merge_options subs, input_block
    Cmds.debug "merged options:",
      options: options

    # build the command string
    cmd = Cmds.sub @template, options[:args], options[:kwds]
    Cmds.debug "built command string: #{ cmd.inspect }"

    out = ''
    err = ''

    Cmds.debug "calling Cmds#really_stream..."
    status = really_stream cmd, options do |io|
      # send the input to stream, which sends it to spawn
      io.in = options[:input]

      # and concat the output lines as they come in
      io.on_out do |line|
        out += line
      end

      io.on_err do |line|
        err += line
      end
    end
    Cmds.debug "Cmds#really_stream completed",
      status: status

    # build a Result
    # result = Cmds::Result.new cmd, status, out_reader.value, err_reader.value
    result = Cmds::Result.new cmd, status, out, err

    # tell the Result to assert if the Cmds has been told to, which will
    # raise a SystemCallError with the exit status if it was non-zero
    result.assert if @assert

    return result
  end # #capture
end