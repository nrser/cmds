class Cmds
  class ERBContext < BasicObject
    def initialize args, kwds
      @args = args
      @kwds = kwds
      @arg_index = 0
    end

    def method_missing sym, *args, &block
      if args.empty? && block.nil?
        if sym.to_s[-1] == '?'
          key = sym.to_s[0...-1].to_sym
          @kwds[key]
        else
          @kwds.fetch sym
        end
      else
        super
      end
    end

    def get_binding
      ::Kernel.send :binding
    end

    def arg
      @args.fetch(@arg_index).tap {@arg_index += 1}
    end
  end # end ERBContext
end # class Cmds