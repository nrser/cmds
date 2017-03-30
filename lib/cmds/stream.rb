require_relative 'spawn'

class Cmds
  # 
  def stream *args, **kwds, &io_block
    Cmds.debug "entering Cmds#stream",
      args: args,
      kwds: kwds,
      io_block: io_block
    
    self.class.spawn prepare(*args, **kwds), @input, &io_block
  end
end