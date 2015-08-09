require 'logger'

# debug logging stuff
class Cmds
  # constants
  THREAD_DEBUG_COLORS = {
    'INPUT' => :cyan,
    'OUTPUT' => :green,
    'ERROR' => :red,
  }

  # class variables
  @@logger = nil  

  # class methods
  # =============

  def self.configure_logger dest = $stdout
    require 'pastel'
    @@pastel = Pastel.new

    @@logger = Logger.new dest
    @@logger.level = Logger::DEBUG
    @@logger.formatter = proc do |severity, datetime, progname, msg|
      if Thread.current[:name]
        msg = "[Cmds #{ severity } - #{ Thread.current[:name ] }] #{msg}\n"

        if color = Cmds::THREAD_DEBUG_COLORS[Thread.current[:name]]
          msg = @@pastel.method(color).call msg
        end

        msg
      else
        "[Cmds #{ severity }] #{msg}\n"
      end
    end
  end

  # log debug stuff
  def self.debug msg, values = {}
    return unless @@logger
    unless values.empty?
      msg += "\n" + values.map {|k, v| "  #{ k }: #{ v.inspect }" }.join("\n")
    end
    @@logger.debug msg
  end
end # class Cmds