# convenience methods

# global methods
# ==============

# @see Cmds.capture
def Cmds template, *args, **kwds, &input_block
  Cmds.capture template, *args, **kwds, &input_block
end


# @see Cmds.ok?
def Cmds? template, *args, **kwds, &io_block
  Cmds.ok? template, *args, **kwds, &io_block
end


# @see Cmds.assert
def Cmds! template, *args, **kwds, &io_block
  Cmds.assert template, *args, **kwds, &io_block
end


module Cmds
  # create a new {Cmd} instance with the template and parameters and
  # calls {Cmd#prepare}.
  # 
  # @param [String] template
  #   ERB template parameters are rendered into to create the command string.
  # 
  # @param [Array<Object>] *args
  #   positional parameters for rendering into the template.
  # 
  # @param [Hash{Symbol => Object}] **kwds
  #   keyword parameters for rendering into the template.
  # 
  # @return [String]
  #   rendered and formatted command string ready to be executed.
  # 
  def self.prepare template, *args, **kwds
    Cmd.new(template).prepare *args, **kwds
  end
  
  
  # create a new {Cmd} from template with parameters and call {Cmds#capture}
  # on it.
  # 
  # @param template (see .prepare)
  # @param *args (see .prepare)
  # @param **kwds (see .prepare)
  # 
  # @param [#call] &input_block
  #   optional block that returns a string or IO-like readable object to be
  #   used as input for the execution.
  # 
  # @return [Result]
  #   result with command string, exist status, stdout and stderr.
  # 
  def self.capture template, *args, **kwds, &input_block
    Cmd.new(template).capture *args, **kwds, &input_block
  end
  
  
  # create a new {Cmd} from template with parameters and call {Cmd#ok?}
  # on it.
  # 
  # @param template (see .prepare)
  # @param *args (see .prepare)
  # @param **kwds (see .prepare)
  # @param &io_block (see Cmds.spawn)
  # 
  # @return [Result]
  #   result with command string, exist status, stdout and stderr.
  # 
  def self.ok? template, *args, **kwds, &io_block
    Cmd.new(template).ok? *args, **kwds, &io_block
  end
  
  
  def self.error? template, *args, **kwds, &io_block
    Cmd.new(template).error? *args, **kwds, &io_block
  end
  
  
  # create a new {Cmd} and 
  def self.assert template, *args, **kwds, &io_block
    Cmd.new(template).capture(*args, **kwds, &io_block).assert
  end
  
  
  def self.stream template, *subs, &input_block
    Cmds::Cmd.new(template).stream *subs, &input_block
  end
  
  
  def self.stream! template, *subs, &input_block
    Cmds::Cmd.new(template, assert: true).stream *subs, &input_block
  end # ::stream!

  
  # creates a new {Cmd}, captures and returns stdout
  # (sugar for `Cmds.capture(template, *args, **kwds, &input_block).out`).
  #
  # @see Cmd.out
  #
  # @param template (see .prepare)
  # @param *args (see .prepare)
  # @param **kwds (see .prepare)
  # @param &input_block (see .capture)
  #
  # @return [String]
  #   the command's stdout.
  #
  def self.out template, *args, **kwds, &input_block
    Cmd.new(template).out *args, **kwds, &input_block
  end
  
  
  # creates a new {Cmd}, captures and returns stdout. raises an error if the 
  # command fails.
  #
  # @see Cmd.out!
  #
  # @param template (see .prepare)
  # @param *args (see .prepare)
  # @param **kwds (see .prepare)
  # @param &input_block (see .capture)
  #
  # @return [String]
  #   the command's stdout.
  #
  # @raise [SystemCallError]
  #   if the command fails (non-zero exit status).
  #
  def self.out! template, *args, **kwds, &input_block
    Cmd.new(template).out! *args, **kwds, &input_block
  end
  
  
  # captures a new {Cmd}, captures and chomps stdout
  # (sugar for `Cmds.out(template, *args, **kwds, &input_block).chomp`).
  #
  # @see .out
  #
  # @param template (see .prepare)
  # @param *args (see .prepare)
  # @param **kwds (see .prepare)
  # @param &input_block (see .capture)
  #
  # @return [String]
  #   the command's chomped stdout.
  #
  def self.chomp template, *args, **kwds, &input_block
    out(template, *args, **kwds, &input_block).chomp
  end
  
  
  # captures and chomps stdout, raising an error if the command fails.
  # (sugar for `Cmds.out!(template, *args, **kwds, &input_block).chomp`).
  #
  # @see .out!
  #
  # @param template (see .prepare)
  # @param *args (see .prepare)
  # @param **kwds (see .prepare)
  # @param &input_block (see .capture)
  #
  # @return [String]
  #   the command's chomped stdout.
  #
  # @raise [SystemCallError]
  #   if the command fails (non-zero exit status).
  #
  def self.chomp! template, *args, **kwds, &input_block
    out!(template, *args, **kwds, &input_block).chomp
  end
  
  
  # captures and returns stderr
  # (sugar for `Cmds.capture(template, *args, **kwds, &input_block).err`).
  #
  # @see .capture
  #
  # @param template (see .prepare)
  # @param *args (see .prepare)
  # @param **kwds (see .prepare)
  # @param &input_block (see .capture)
  #
  # @return [String]
  #   the command's stderr.
  #
  def self.err template, *args, **kwds, &input_block
    capture(template, *args, **kwds, &input_block).err
  end
end # Cmds
