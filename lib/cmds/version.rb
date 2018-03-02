require 'pathname'

class Cmds
  
  # Constants
  # ============================================================================
  
  # Absolute, expanded path to the gem's root directory.
  # 
  # @return [Pathname]
  # 
  ROOT = (Pathname.new( __FILE__ ).dirname / '..' / '..').expand_path
  
  
  # Library version string.
  # 
  # @return [String]
  # 
  VERSION = '0.2.10.dev'
  
end
