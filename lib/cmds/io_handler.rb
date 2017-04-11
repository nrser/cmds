class Cmds
  class IOHandler
    attr_accessor :in, :out, :err

    def initialize
      @queue = Queue.new
      @in = nil
      @out = $stdout
      @err = $stderr
    end

    def on_out &block
      @out = block
    end

    # called in seperate thread handling process IO
    def thread_send_out line
      @queue << [:out, line]
    end

    def on_err &block
      @err = block
    end

    # called in seperate thread handling process IO
    def thread_send_err line
      @queue << [:err, line]
    end

    def thread_send_line sym, line
      @queue << [sym, line]
    end

    def start
      # if out is a proc, it's not done
      out_done = ! @out.is_a?(Proc)
      # same for err
      err_done = ! @err.is_a?(Proc)

      until out_done && err_done
        key, line = @queue.pop
        
        case key
        when :out
          if line.nil?
            out_done = true
          else
            handle_line @out, line
          end

        when :err
          if line.nil?
            err_done = true
          else
            handle_line @err, line
          end

        else
          raise "bad key: #{ key.inspect }"
        end
      end
    end #start

    private

      def handle_line dest, line
        if dest.is_a? Proc
          dest.call line
        else
          dest.puts line
        end
      end

    # end private
  end # end IOHandler
end # class Cmds