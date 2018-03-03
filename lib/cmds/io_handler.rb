class Cmds
  # Class for handling IO from threads and passing it back via a {Queue} to
  # the main thread for processing.
  # 
  # NOTE  These are one-use only! Don't try to reuse them.
  # 
  class IOHandler
    attr_accessor :in, :out, :err

    def initialize
      @in = nil
      @out = $stdout
      @err = $stderr
      
      # Initialize a thread-safe queue for passing output from the IO threads
      # back to the main thread
      # 
      # NOTE  This used to be done in {#start}, but I was seeing intermittent
      #       failures on Travis from what look like thread race conditions,
      #       guessing that it's from output arriving before {#start} is
      #       called, which totally looks like it could happen.
      #       
      #       See the failure in
      #       
      #       https://travis-ci.org/nrser/qb/jobs/348609316
      #       
      #       Really, I'm surprised I haven't hit more issues with this
      #       half-ass threading shit.
      #       
      #       Anyways, I moved the queue creation here, see if it helps.
      # 
      @queue = Queue.new
      
      # Flag that is set to `true` when {#start} is called.
      @started = false
    end
    
    def out= value
      value = value.to_s if value.is_a? Pathname
      @out = value
    end
    
    def err= value
      value = value.to_s if value.is_a? Pathname
      @err = value
    end

    def on_out &block
      @out = block
    end

    # called in separate thread handling process IO
    def thread_send_out line
      @queue << [:out, line]
    end

    def on_err &block
      @err = block
    end

    # called in separate thread handling process IO
    def thread_send_err line
      @queue << [:err, line]
    end
    
    # called in separate thread handling process IO
    def thread_send_line sym, line
      @queue << [sym, line]
    end

    def start
      if @started
        raise "This handler has already been started / run"
      end
      
      @started = true
      
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
