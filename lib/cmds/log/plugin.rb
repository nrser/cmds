require 'semantic_logger'
require 'cmds/refine'

using Cmds::Refine

module Cmds
  module Log
    # Abstract base class that wraps a {Cmds::Log::Logger} and exposes the
    # level logging methods - `#debug`, `#info`, etc. - routing those calls
    # through it's {#call} method and on to the logger's method, allowing
    # concrete subclasses to hook into those calls and provide additional
    # functionality and logic.
    #
    # Convention is
    #
    # @abstract
    #
    # @see Cmds::Log::Logger::Catcher
    # @see Cmds::Log::Logger::Notifier
    #
    # @todo
    #   Make plugins "stackable".
    #
    #   Not sure if this example in particular would make any sense, but you can
    #   get the idea:
    #
    #       logger.notify.catcher.warn
    #
    class Plugin
      # Class Methods
      # ========================================================================

      # The {Cmds::Log::Logger} method name that will create plugin instances.
      #
      # Looks for the `@method_name` class instance variable, and defaults to
      # `safe_name.demodulize.underscore` if that is not found.
      #
      # @return [Symbol | String]
      #
      def self.method_name
        @method_name || safe_name.demodulize.underscore
      end # .method_name

      # Attributes
      # ========================================================================

      # The wrapped logger instance.
      #
      # @return [Cmds::Log::Logger]
      #
      attr_reader :logger

      # Construction
      # ========================================================================

      # Instantiate a new plugin instance.
      #
      # @param [Cmds::Log::Logger] logger
      #   The wrapper logger instance.
      #
      def initialize(logger)
        @logger = logger
      end # #initialize

      # Instance Methods
      # ========================================================================

      # This is where realizing subclasses can hook into log calls.
      #
      # This base implementation just calls the `level` method on {#logger}
      # with the `args` and `block`.
      #
      # @note
      #   Though the logging methods don't use a block at this time, it's there
      #   for completeness and possible futures.
      #
      # @param [Symbol] level
      #   The log level of the call; one of {SemanticLogger::LEVELS}.
      #
      # @param [String?] message
      #   Log message.
      #
      # @param [Hash?] payload
      #   Map of names to values to log.
      #
      # @param [Object?] exception
      #   An error to log. This will be an {Exception} in MRI, but *won't* be in
      #   JRuby and possibly other runtimes.
      #
      # @param [Object?] metric
      #   I don't know what this is. I found it in the SemLog code.
      #
      # @param [Proc] block
      #   Block to pass to the {#logger}'s `level` method. Not currently used
      #   (see note above).
      #
      def call(level:, message:, payload:, exception:, metric:, &block)
        logger.send \
          level,
          message: message,
          payload: payload,
          exception: exception,
          metric: metric,
          &block
      end

      # Dynamically define each logging method.
      SemanticLogger::LEVELS.each do |level|
        define_method level do |*args, &block|
          call level: level, **Cmds::Log::Logger.args_to_kwds(*args), &block
        end
      end

      # @return [String]
      #   Short string description of the instance.
      def to_s
        "#<#{self.class.safe_name} #{logger}>"
      end
    end # class Plugin
  end # module Log
end # module Cmds
