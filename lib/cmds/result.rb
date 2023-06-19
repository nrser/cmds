class Cmds
  # A simple data structure returned from calling {Cmds#capture}
  # on a {Cmds} instance.
  #
  # It contains the exit status code, standard output and standard error,
  # as well as the actual string command issued (after all substitutions).
  #
  # Instances also have a few convenience methods.
  #
  class Result
    # The command string that was executed.
    #
    # @return [String]
    #
    attr_reader :cmd

    # The command process' exit status code.
    #
    # @return [Fixnum]
    #
    attr_reader :status

    # The command process' standard output.
    #
    # @return [String]
    #
    attr_reader :out

    # The command process' standard error.
    #
    # @return [String]
    #
    attr_reader :err

    # @param cmd [String] {#cmd} attribute.
    # @param status [Fixnum] {#status} attribute.
    # @param out [String] {#out} attribute.
    # @param err [String] {#err} attribute.
    def initialize(cmd, status, out, err)
      @cmd = cmd
      @status = status
      @out = out
      @err = err
    end

    # @return [Boolean]
    #   `true` if {#status} is `0`.
    def ok?
      @status == 0
    end

    # @return [Boolean]
    #   `true` if {#status} is not `0`.
    def error?
      !ok?
    end

    # Raises an error if the command failed (exited with a {#status} other
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

    # Get a {Hash} containing the instance variable values for easy logging,
    # JSON dumping, etc.
    #
    # @example
    #   Cmds( "echo %s", "hey" ).to_h
    #   # => {:cmd=>"echo hey", :status=>0, :out=>"hey\n", :err=>""}
    #
    # @return [Hash<Symbol, V>]
    #
    def to_h
      instance_variables.map do |name|
        [name.to_s.sub('@', '').to_sym, instance_variable_get(name)]
      end.to_h
    end

    def json
      JSON.load out
    end
  end # Result
end # Cmds
