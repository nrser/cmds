require 'semantic_logger'
require 'cmds/refine'

using Cmds::Refine

# Extension of {SemanticLogger::Logger} to add and customize behavior.
#
class Cmds::Log::Logger < SemanticLogger::Logger
  # Classes
  # ========================================================================

  # Class that points to a {Cmds::Log::Logger} and provides the log methods
  # (`#error`, `#warn`, ... `#trace`) with an additional `&block` parameter.
  #
  # Each of those methods calls the block in a `begin` / `rescue`, and if it
  # raises, the log message will be dispatched with the raised error added.
  #
  # @see Cmds::Log::Logger#catch
  #
  class Catcher
    # Construction
    # ========================================================================

    # Instantiate a new `Catcher`.
    #
    # @param [Cmds::Log::Logger] logger
    #   The logger to use if the block raises.
    #
    # @param [*] on_fail
    #   Value to return when `&block` raises.
    #
    def initialize(logger, on_fail: nil)
      @logger = logger
      @on_fail = on_fail
    end # #initialize

    # Instance Methods
    # ========================================================================

    SemanticLogger::LEVELS.each do |level|
      define_method level do |message = nil, payload = nil, &block|
        block.call
      rescue Exception => e
        @logger.send level, message, payload, e
        @on_fail
      end
    end
  end # class Catcher

  # Under JRuby a java exception is not a Ruby Exception
  #
  #   Java::JavaLang::ClassCastException.new.is_a?(Exception) => false
  #
  def self.is_exception?(value)
    value.is_a?(Exception) ||
      %i[backtrace message].all? { |name| value.respond_to? name }
  end

  # Normalizes the valid argument formats to {SemanticLogger::Logger}'s
  # "standard logging methods" into a keywords hash.
  #
  # By "standard logging methods", we mean {SemanticLogger::Logger#debug},
  # {SemanticLogger::Logger#info}, etc., as detailed in the
  # [Semantic Logger API][] documentation.
  #
  # [Semantic Logger API]: https://rocketjob.github.io/semantic_logger/api.html
  #
  # Semantic Logger documents the standard logging methods API as
  #
  #     log.info(message, payload_or_exception = nil, exception = nil, &block)
  #
  # or
  #
  #     logger.info(
  #       message: String?,
  #       payload: Hash?,
  #       exception: Object?,
  #       **metric_keywords
  #     )
  #
  # Which means that the hash returned by this method can be used as the
  # argument to the standard logging methods:
  #
  #     def proxy_info_call *args, &block
  #       logger.info **Cmds::Log::Logger.args_to_kwds( *args ), &block
  #     end
  #
  # This makes this method very useful when pre-processing log call arguments,
  # as is done in {Cmds::Log::Plugin} before passing the resulting keywords
  # to {Cmds::Log::Plugin#call} because the hash this method returns is much
  # easier to work with than the standard logging methods' multiple valid
  # argument formats.
  #
  # @param [Array] args
  #   Valid arguments for {SemanticLogger::Logger#debug}, etc. - see notes
  #   above.
  #
  # @return [Hash<Symbol, Object>]
  #   Always has the following keys (**all** of which can have `nil` value):
  #
  #   -   `message: String?` - we don't actually check that it's a {String},
  #       but that seems to be pretty much what Semantic Logger expects.
  #
  #   -   `payload: Hash?` - A hash of names to values to log. By convention
  #       names are {Symbol}, though I'm not sure what happens if they are not.
  #
  #   -   `exception: Object?` - An error to log. This will be an {Exception}
  #       in MRI. In JRuby, and perhaps elsewhere, they won't be, but they
  #       should always respond to `#message` and `#backtrace`.
  #
  #   -   `metric: Object?` -
  #
  def self.args_to_kwds *args
    log_kwds = {
      message: nil,
      payload: nil,
      exception: nil,
      metric: nil
    }

    case args.length
    when 0
      # pass - they all stay `nil` (which it seems SemLog allows, so we'll
      # stick to it)

    when 1
      case args[0]
      when Hash
        if %i[message payload exception metric]
           .any? { |key| args[0].key? key }
          log_kwds = args[0]
        else
          # It's the payload
          log_kwds[:payload] = args[0]
        end
      else
        if is_exception? args[0]
          # It's the exception
          log_kwds[:exception] = args[0]
        else
          # It's got to be the message
          log_kwds[:message] = args[0]
        end
      end

    when 2
      if args[0].is_a? Hash
        log_kwds[:payload] = args[0]
        log_kwds[:exception] = args[1]
      else
        log_kwds[:message] = args[0]

        if args[1].is_a? Hash
          log_kwds[:payload] = args[1]
        else
          log_kwds[:exception] = args[1]
        end
      end

    when 3
      log_kwds[:message] = args[0]
      log_kwds[:payload] = args[1]
      log_kwds[:exception] = args[2]

    else
      raise Cmds::ArgumentError.new \
        'Too many args dude - max 3',
        args: args

    end

    log_kwds
  end # .normalize_log_args

  # Install a plugin, dynamically adding it's
  # {Cmds::Log::Plugin.method_name} instance method.
  #
  # @param [Class<Cmds::Log::Plugin>] plugin_class
  #   The plugin class to add.
  #
  # @return [nil]
  #
  # @raise [Cmds::ConflictError]
  #   If this class already has an instance method defined with the name
  #   returned from `plugin_class.method_name`.
  #
  def self.plugin(plugin_class)
    method_name = plugin_class.method_name

    if instance_methods.include? method_name.to_sym
      raise Cmds::ConflictError.new \
        'Can not install', plugin_class.safe_name,
        'Logger plugin: instance method', method_name, 'already defined'
    end

    define_method method_name do |*args, &block|
      plugin_class.new self, *args, &block
    end

    nil
  end # .plugin

  # Attributes
  # ========================================================================

  # TODO: document `awesome_name` attribute.
  #
  # @return [String]
  #
  attr_reader :awesome_name

  # Constructor
  # ========================================================================

  # Overrides {SemanticLogger::Logger#initialize}¹ to extend "subject" support
  # to instances (as well as modules/classes and strings).
  #
  # > ¹ {SemanticLogger::Logger#initialize} is just a proxy to
  # >   {SemanticLogger::Base#initialize}, which is what this implementation
  # >   is based off.
  #
  # @param [Module | String | INSTANCE] subject
  #   Name of the class, module, or other identifier for which the log messages
  #   are being logged
  #
  # @param [nil | Symbol] level
  #   Only allow log entries of this level or higher to be written to this
  #   appender For example if set to :warn, this appender would only log
  #   `:warn` and `:fatal` log messages when other appenders could be logging
  #   `:info` and lower.
  #
  # @param [nil | Regexp | Proc<(SemanticLogger::Log) => Boolean>] filter
  #   1.  {RegExp}: Only include log messages where the class name matches
  #       the supplied regular expression. All other messages will be
  #       ignored.
  #
  #   2.  {Proc}: Only include log messages where the supplied Proc returns
  #       `true`.
  #
  # @raise [Cmds::TypeError]
  #   If `filter:` is not an acceptable type.
  #
  def initialize(subject, level: nil, filter: nil)
    # Support filtering all messages to this logger using a Regular Expression
    # or Proc
    unless filter.nil? || filter.is_a?(Regexp) || filter.is_a?(Proc)
      raise Cmds::TypeError,
            ':filter must be a Regexp or Proc',
            filter: filter,
            subject: subject,
            level: level
    end

    @filter = filter.is_a?(Regexp) ? filter.freeze : filter

    # @name   = klass.is_a?(String) ? klass : klass.name
    case subject
    when String
      @name = subject
      @awesome_name = subject
      @type = :string

    when Module
      @name = subject.safe_name
      @awesome_name = subject.ai multiline: true, raw: true
      @type = subject.is_a?(Class) ? :class : :module

    else
      @name = subject.to_s
      @awesome_name = subject.ai multiline: true, raw: true
      @type = :instance

    end

    if level.nil?
      # Allow the global default level to determine this loggers log level
      @level_index = nil
      @level       = nil
    else
      self.level = level
    end
  end

  # Instance Methods
  # ========================================================================

  # Log message at the specified level
  def build_log(level,
                index,
                message = nil,
                payload = nil,
                exception = nil,
                &block)
    log        = SemanticLogger::Log.new name, level, index
    should_log =
      if payload.nil? && exception.nil? && message.is_a?(Hash)
        # Check if someone just logged a hash payload instead of meaning to call semantic logger
        if  message.key?(:message) ||
            message.key?(:payload) ||
            message.key?(:exception) ||
            message.key?(:metric)
          log.assign message
        else
          log.assign_positional nil, message, nil, &block
        end
      else
        log.assign_positional message, payload, exception, &block
      end

    # Log level may change during assign due to :on_exception_level
    [log, should_log && should_log?(log)]
  end

  # Log message at the specified level
  # def log_internal *args, &block
  #   log, should_log = build_log *args
  #   self.log( log ) if should_log
  # end

  # A sweet way to try something and just log any {Exception}.
  #
  # Useful for situations where the operation is question is not necessary
  # or can not be allowed to propagate errors, but you would like to record
  # and/or let the user know that it failed.
  #
  # Create a new {Catcher} for this logger that defines the log methods
  # (`#error`, `warn`, ... `:trace`) to also accept blocks that will be
  # executed in a `begin`/`rescue`.
  #
  # If the block raises, the catcher will call the log method, adding the
  # caught {Exception}.
  #
  # @example Log any error as a warning
  #   logger.catch.warn do
  #     something_that_may_raise
  #   end
  #
  #   # We should "always" get to here
  #
  # @example Log any error as warning with message and payload
  #   logger.catch.warn(
  #     "This thing failed!",
  #     some_detail: some_value,
  #   ) do
  #     something_that_may_raise
  #   end
  #
  #   # We should "always" get to here
  #
  # @example Return a custom value on error
  #   result = logger.catch( on_fail: :blue ).debug do
  #     what_is_your_favorite_color?
  #   end
  #
  # @param [Hash] options
  #   Passed to {Catcher#initialize}.
  #
  # @return [Catcher]
  #
  def catch **options
    Catcher.new self, **options
  end # #catch

  # Set the level for the execution of `&block`, restoring it to it's previous
  # level afterwards.
  #
  # Like what {SemanticLogger::Logger#silence} does (which just forwards to
  # {SemanticLogger.silence}), but applies only to *this* logger (where as
  # {SemanticLogger::Logger#silence} applies on to the global default level).
  #
  # Useful for quickly turning down the log level to see trace/debug output
  # from a specific section.
  #
  # @param [Symbol?] level
  #   One of {SemanticLogger::LEVELS} or `nil` to use the global default level.
  #
  # @param [Proc<() => RESULT>] block
  #   Block to execute with the `level`.
  #
  # @return [RESULT]
  #   Whatever `&block` returns.
  #
  def with_level(level, &block)
    prior_level = @level
    self.level = level

    begin
      block.call
    ensure
      self.level = prior_level
    end
  end
end # class Cmds::Log::Logger
