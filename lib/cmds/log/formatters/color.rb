# Requirements
# =======================================================================

# Stdlib
# -----------------------------------------------------------------------

# Deps
# -----------------------------------------------------------------------
require 'amazing_print'
require 'semantic_logger'

# Project / Package
# -----------------------------------------------------------------------

require_relative './mixin'

# Refinements
# =======================================================================


# Declarations
# =======================================================================

module Cmds::Log; end
module Cmds::Log::Formatters; end


# Definitions
# =======================================================================

class Cmds::Log::Formatters::Color < ::SemanticLogger::Formatters::Color
  
  # Constants
  # ======================================================================
  
  # ANSI escape sequence to start "Dark Gray" color.
  # 
  # @return [String]
  # 
  ANSI_ESC_DARK_GRAY = "\e[1;30m"
  
  
  # Mixins
  # ========================================================================
  
  include Cmds::Log::Formatters::Mixin
  
  
  # Class Methods
  # ======================================================================
  
  # @todo Document default_color_map method.
  # 
  # @return [SemanticLogger::Formatters::Color::ColorMap]
  # 
  def self.default_color_map
    SemanticLogger::Formatters::Color::ColorMap.new(
      debug: SemanticLogger::AnsiColors::MAGENTA,
      trace: ANSI_ESC_DARK_GRAY,
      warn: SemanticLogger::AnsiColors::YELLOW,
    )
  end # .default_color_map
  
  
  # A **HACK** to get an {AwesomePrint::Formatter} to
  # {AwesomePrint::Formatter#colorize} with by constructing a new
  # {AwesomePrint::Inspector} and fishing it out of the `@formatter`
  # instance variable.
  # 
  # This is only done once and the value is cached in a class variable.
  # 
  # @see .colorize
  # 
  # @private
  # @return [AwesomePrint::Formatter]
  # 
  def self.ap_formatter
    @@ap_formatter ||= \
      AwesomePrint::Inspector.new.instance_variable_get :@formatter
  end
  
  private_class_method :ap_formatter
  
  
  def self.colorize string, type
    ap_formatter.colorize string, type
  end
  
  
  # Attributes
  # ======================================================================
  
  
  # Constructor
  # ======================================================================
  
  # Instantiate a new `ColorFormatter`.
  def initialize  ap: {multiline: true }, # raw: true},
                  color_map: self.class.default_color_map,
                  time_format: nil,
                  log_host: false,
                  log_application: false
    super ap: ap,
          color_map: color_map,
          time_format: time_format,
          log_host: log_host,
          log_application: log_application
  end # #initialize
  
  
  # Instance Methods
  # ======================================================================
  
  def name
    self.class.colorize log.name, :class
  end
  
  
  # Upcase the log level.
  # 
  # @return [String]
  # 
  def level
    "#{ color }#{ log.level.upcase }#{ color_map.clear }"
  end
  
  
  def time
    "#{ color }#{ super() }#{ color_map.clear }"
  end
  
  
  # Create the log entry text. Overridden to customize appearance -
  # generally reduce amount of info and put payload on it's own line.
  # 
  # We need to replace *two* super functions, the first being
  # [SemanticLogger::Formatters::Color#call][]:
  # 
  #     def call(log, logger)
  #       self.color = color_map[log.level]
  #       super(log, logger)
  #     end
  # 
  # [SemanticLogger::Formatters::Color#call]: https://github.com/rocketjob/semantic_logger/blob/v4.2.0/lib/semantic_logger/formatters/color.rb#L98
  # 
  # which doesn't do all too much, and the next being it's super-method,
  # [SemanticLogger::Formatters::Default#call][]:
  #     
  #     # Default text log format
  #     #  Generates logs of the form:
  #     #    2011-07-19 14:36:15.660235 D [1149:ScriptThreadProcess] Rails -- Hello World
  #     def call(log, logger)
  #       self.log    = log
  #       self.logger = logger
  #     
  #       [time, level, process_info, tags, named_tags, duration, name, message, payload, exception].compact.join(' ')
  #     end
  # 
  # [SemanticLogger::Formatters::Default#call]: https://github.com/rocketjob/semantic_logger/blob/v4.2.0/lib/semantic_logger/formatters/default.rb#L64
  # 
  # which does most the real assembly.
  # 
  # @param [SemanticLogger::Log] log
  #   The log entry to format.
  #   
  #   See [SemanticLogger::Log](https://github.com/rocketjob/semantic_logger/blob/v4.2.0/lib/semantic_logger/log.rb)
  # 
  # @param [SemanticLogger::Logger] logger
  #   The logger doing the logging (pretty sure, haven't checked).
  #   
  #   See [SemanticLogger::Logger](https://github.com/rocketjob/semantic_logger/blob/v4.2.0/lib/semantic_logger/logger.rb)
  # 
  # @return [return_type]
  #   @todo Document return value.
  # 
  def call log, logger
    # SemanticLogger::Formatters::Color code
    self.color = color_map[log.level]
    
    # SemanticLogger::Formatters::Default code
    self.log    = log
    self.logger = logger
    
    render_log
    
  end # #call
  
  
end # class Color
