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
    Cmds.debug "entering Cmd#stream",
      args: args,
      kwds: kwds,
      io_block: io_block
    
    Cmds.spawn  prepare(*args, **kwds),
                input: @input,
                # include env if mode is spawn argument
                env: (@env_mode == :spawn_arg ? @env : {}),
                chdir: @chdir,
                &io_block
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
    cmd = prepare(*args, **kwds)
    
    status = Cmds.spawn cmd,
                        input: @input,
                        # include env if mode is spawn argument
                        env: (@env_mode == :spawn_arg ? @env : {}),
                        chdir: @chdir,
                        &io_block
    
    Cmds.check_status cmd, status
    
    status
  end # #stream!
end # Cmds