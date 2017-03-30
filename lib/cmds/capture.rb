require_relative 'spawn'

class Cmds
  # executes the command and returns a {Cmds::Result} with the captured
  # outputs.
  # 
  # @param [Array<Object>] *args
  #   positional parameters to append to those in `@args` for substitution 
  #   into the command string.
  # 
  # @param [Hash{Symbol => Object}] **kwds
  #   keyword parameters that override those in `@kwds` for substitution
  #   into the command string.
  # 
  # @param [#call] &input
  #   optional block that returns a string or readable object to override
  #   `@input`.
  # 
  # @return [Cmds::Result]
  #   result of execution with command string, status, stdout and stderr.
  # 
  def capture *args, **kwds, &input
    Cmds.debug "entering Cmds#capture",
      args: args,
      kwds: kwds,
      input: input
    
    # prepare the command string
    cmd = prepare *args, **kwds
    
    # extract input from block via `call` if one is provided,
    # otherwise default to instance variable (which may be `nil`)
    input = input.nil? ? @input : input.call
    
    Cmds.debug "prepared",
      cmd: cmd,
      input: input
    
    # strings output will be concatenated onto
    out = ''
    err = ''

    Cmds.debug "calling Cmds#really_stream..."
    
    status = self.class.spawn cmd do |io|
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