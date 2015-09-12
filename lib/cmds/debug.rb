require 'logger'

# debug logging stuff
class Cmds

  module Debug
    # constants

    # change the color of debug output by thread name (if present)
    THREAD_COLORS = {
      'INPUT' => :cyan,
      'OUTPUT' => :green,
      'ERROR' => :red,
    }
    # available Pastel styles:
    # 
    # clear, reset, bold, dark, dim, italic, underline, underscore, inverse, hidden, strikethrough,
    # black, red, green, yellow, blue, magenta, cyan, white, 
    # on_black, on_red, on_green, on_yellow, on_blue, on_magenta, on_cyan, on_white, 
    # bright_black, bright_red, bright_green, bright_yellow, bright_blue, bright_magenta, bright_cyan, bright_white,
    # on_bright_black, on_bright_red, on_bright_green, on_bright_yellow, on_bright_blue, on_bright_magenta, on_bright_cyan, on_bright_white
    # 

    # class variables
    @@on = false
    @@logger = nil

    # class methods
    # =============

    # get the Logger instance. may be `nil`.
    def self.logger
      @@logger
    end

    # test if the logger is configured.
    def self.configured?
      !! @@logger
    end

    # configure the Logger with optional destination
    def self.configure dest = $stdout
      require 'pastel'
      @@pastel = Pastel.new

      @@logger = Logger.new dest
      @@logger.level = Logger::DEBUG
      @@logger.formatter = proc do |severity, datetime, progname, msg|
        if Thread.current[:name]
          msg = "[Cmds #{ severity } - #{ Thread.current[:name ] }] #{msg}\n"

          if color = THREAD_COLORS[Thread.current[:name]]
            msg = @@pastel.method(color).call msg
          end

          msg
        else
          "[Cmds #{ severity }] #{msg}\n"
        end
      end
    end

    # turn debug logging on. if you provide a block it will turn debug logging
    # on for that block and off at the end.
    def self.on &block
      configure unless configured?
      @@on = true
      if block
        yield
        off
      end
    end

    # turn debug logging off.
    def self.off
      @@on = false
    end

    # test if debug logging is on.
    def self.on?
      @@on
    end

    # format a debug message with optional key / values to print
    def self.format msg, values = {}
      if values.empty?
        msg
      else
        msg + "\n" + values.map {|k, v| "  #{ k }: #{ v.inspect }" }.join("\n")
      end
    end

  end # module Debug

  # log a debug message along with an optional hash of values.
  def self.debug msg, values = {}
    # don't even bother unless debug logging is turned on
    return unless Cmds::Debug.on?
    Debug.logger.debug format(msg, values)
  end
end # class Cmds