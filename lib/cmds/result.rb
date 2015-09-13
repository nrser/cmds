class Cmds
  class Result
    attr_reader :cmd, :status, :out, :err

    def initialize cmd, status, out, err
      @cmd = cmd
      @status = status
      @out = out
      @err = err
    end

    def ok?
      @status == 0
    end

    def error?
      ! ok?
    end

    # raises an error if there was one
    # returns the Result so that it can be chained
    def assert
      if error?
        msg = NRSER.squish <<-BLOCK
          command `#{ @cmd }` exited with status #{ @status }
          and stderr #{ err.inspect }
        BLOCK

        raise SystemCallError.new msg, @status
      end
      self
    end # raise_error
  end
end # class Cmds