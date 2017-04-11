class Cmds
  class ERBContext < BasicObject
    attr_reader :args
    
    def initialize args, kwds
      @args = args
      @kwds = kwds
      @arg_index = 0
    end

    def method_missing sym, *args, &block
      if args.empty? && block.nil?
        if sym.to_s[-1] == '?'
          key = sym.to_s[0...-1].to_sym
          # allow `false` to be omitted as well as missing and `nil`
          # by returning `nil` if the value is "false-y"
          @kwds[key] if @kwds[key]
        else
          if @kwds.key? sym
            @kwds[sym]
          elsif @kwds.key? sym.to_s
            @kwds[sym.to_s]
          else
            ::Kernel.raise ::KeyError.new ::NRSER.squish <<-END
              couldn't find keys #{ sym.inspect } or #{ sym.to_s.inspect }
              in keywords #{ @kwds.inspect }
            END
          end
        end
      else
        super sym, *args, &block
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
