class Cmds
  # stupid little wrapper around IO.pipe that can have some extra info
  # attached to it
  class Pipe
    attr_reader :name, :sym, :r, :w

    def initialize name, sym
      @name = name
      @sym = sym
      @r, @w = IO.pipe
    end
  end
end