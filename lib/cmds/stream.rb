class Cmds
  # stream a command.
  # 
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # 
  # @param [nil | String | #read] &io_block
  #   string or readable IO-like object to use as input to the command.
  # 
  # @return [Fixnum]
  #   command exit status.
  # 
  def stream *args, **kwds, &io_block
    Cmds.debug "entering Cmds#stream",
      args: args,
      kwds: kwds,
      io_block: io_block
    
    spawn *args, **kwds, &io_block
  end # #stream

  # stream and raise an error if exit code is not 0.
  # 
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # @param &io_block (see #stream)
  # @return [Fixnum] (see #stream)
  # 
  # @raise [SystemCallError]
  #   if exit status is not 0.
  # 
  def stream! *args, **kwds, &io_block
    status = stream *args, **kwds, &io_block
    
    Cmds.check_status last_prepared_cmd, status
    
    status
  end # #stream!
end # Cmds