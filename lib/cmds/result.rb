require 'nrser/refinements'

class Cmds
  # a simple data structure returned from calling {Cmds#capture} 
  # on a {Cmd} instance.
  # 
  # it contains the exit status code, standard output and standard error,
  # as well as the actual string command issued (after all substitutions).
  #
  # instances also have a few convenience methods.
  #
  # @!attribute [r] cmd
  #   @return [String] the command string that was executed.
  #
  # @!attribute [r] status
  #   @return [Fixnum] the command process' exit status code.
  #
  # @!attribute [r] out
  #   @return [String] the command process' standard output.
  #
  # @!attribute [r] err
  #   @return [String] the command process' standard error.
  #
  class Result
    attr_reader :cmd, :status, :out, :err
    
    # @param cmd [String] {#cmd} attribute.
    # @param status [Fixnum] {#status} attribute.
    # @param out [String] {#out} attribute.
    # @param err [String] {#err} attribute.
    def initialize cmd, status, out, err
      @cmd = cmd
      @status = status
      @out = out
      @err = err
    end
    
    # @return [Boolean] true if {#status} is `0`.
    def ok?
      @status == 0
    end
    
    # @return [Boolean] true if {#status} is not `0`.
    def error?
      ! ok?
    end
    
    # raises an error if the command failed (exited with a {#status} other 
    # than `0`).
    #
    # @return [Result] it's self (so that it can be chained).
    #
    # @raise [SystemCallError] if the command failed.
    #
    def assert
      Cmds.check_status @cmd, @status, @err
      self
    end # raise_error
  end # Result
end # Cmds
