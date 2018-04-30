class Cmds
  
  # executes the command and returns a {Cmds::Result} with the captured
  # outputs.
  # 
  # @param [Array<Object>] *args
  #   positional parameters to append to those in `@args` for rendering
  #   into the command string.
  # 
  # @param [Hash{Symbol => Object}] **kwds
  #   keyword parameters that override those in `@kwds` for rendering
  #   into the command string.
  # 
  # @param [#call] &input_block
  #   optional block that returns a string or readable object to override
  #   `@input`.
  # 
  # @return [Cmds::Result]
  #   result of execution with command string, status, stdout and stderr.
  # 
  def capture *args, **kwds, &input_block
    logger.trace "entering Cmds#capture",
      args: args,
      kwds: kwds,
      input: input
    
    # extract input from block via `call` if one is provided,
    # otherwise default to instance variable (which may be `nil`)
    input = input_block.nil? ? input : input_block.call
    
    logger.trace "configured input",
      input: input
    
    # strings output will be concatenated onto
    out = ''
    err = ''

    logger.trace "calling Cmds.spawn..."
    
    status = spawn(*args, **kwds) do |io|
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
    
    logger.trace "Cmds.spawn completed",
      status: status

    # build a Result
    # result = Cmds::Result.new cmd, status, out_reader.value, err_reader.value
    result = Cmds::Result.new last_prepared_cmd, status, out, err

    # tell the Result to assert if the Cmds has been told to, which will
    # raise a SystemCallError with the exit status if it was non-zero
    result.assert if assert

    return result
  end # #capture


  alias_method :call, :capture
  
end # class Cmds
