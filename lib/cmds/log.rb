# frozen_string_literal: true

# Requirements
# =======================================================================

# Stdlib
# -----------------------------------------------------------------------

# Deps
# -----------------------------------------------------------------------

# What Cmds's logging is based off
require 'semantic_logger'

# Project / Package
# -----------------------------------------------------------------------

# Definitions
# =======================================================================

# Unified logging support via {SemanticLogger}.
#
# @see https://rocketjob.github.io/semantic_logger/index.html
#
class Cmds
  module Log
    # Sub-Tree Requirements
    # ========================================================================

    require_relative './log/mixin'
    require_relative './log/logger'
    require_relative './log/formatters'

    # Mixins
    # ========================================================================

    # Mix in {.logger} and {#logger}
    include Mixin

    # We want to forward some methods directly to {SemanticLogger}
    extend SingleForwardable

    # Delegation
    # ========================================================================
    #
    # Send some things up to {SemanticLogger}.
    #

    def_single_delegators(
      SemanticLogger,
      :application,
      :application=,
      :[]
      # NOTE: These are funky due to different in SemLog's int level and Ruby
      #       stdlib / Rails logger int levels, so omit for now.
      #
      # :index_to_level,
      # :level_to_index
    )

    # Constants
    # ==========================================================================

    # Down-cased versions of strings that are considered to communicate true
    # in things like ENV vars, CLI options, etc.
    #
    # @return [Set<String>]
    #
    TRUTHY_STRINGS = Set.new %w[
      true
      t
      yes
      y
      on
      1
    ].freeze

    # Down-cased versions of strings that are considered to communicate false
    # in things like ENV vars, CLI options, etc.
    #
    # @return [Set<String>]
    #
    FALSY_STRINGS = Set.new [
      'false',
      'f',
      'no',
      'n',
      'off',
      '0',
      ''
    ].freeze

    # Module Attributes
    # ========================================================================

    # Used in {.setup!} to make sure we don't have multiple threads trying to
    # muck around at the same time.
    #
    @__mutex__ = Mutex.new

    # Class Methods
    # ========================================================================

    # Evaluate an object (that probably came from outside Ruby, like an
    # environment variable) to see if it's meant to represent true or false.
    #
    # @pure Return value depends only on parameters.
    #
    # @param [nil | String | Boolean] object
    #   Value to test.
    #
    # @return [Boolean]
    #   `true` if the object is "truthy".
    #
    # @raise [ArgumentError]
    #   When a string is received that is not in {NRSER::TRUTHY_STRINGS} or
    #   {NRSER::FALSY_STRINGS} (case insensitive).
    #
    # @raise [TypeError]
    #   When `object` is not the right type.
    #
    def self.truthy?(object)
      case object
      when nil
        false

      when String
        downcased = object.downcase

        if TRUTHY_STRINGS.include? downcased
          true
        elsif FALSY_STRINGS.include? downcased
          false
        else
          raise ArgumentError,
                "String #{object.inspect} not recognized as true or false."
        end

      when TrueClass, FalseClass
        object

      else
        raise TypeError,
              "Can't evaluate truthiness of #{object.inspect}"
      end
    end # .truthy?

    # Opposite of {truthy?}.
    #
    # @pure Return value depends only on parameters.
    #
    # @param object (see .truthy?)
    #
    # @return [Boolean]
    #   The negation of {truthy?}.
    #
    # @raise [ArgumentError]
    #   When a string is received that is not in {TRUTHY_STRINGS} or
    #   {FALSY_STRINGS} (case insensitive).
    #
    # @raise [TypeError]
    #   When `object` is not the right type.
    #
    def self.falsy?(object)
      !truthy?(object)
    end

    def self.logger_for(subject)
      Cmds::Log::Logger.new subject
    end

    singleton_class.send :alias_method, :[], :logger_for

    # @!group Utility Class Methods
    # ------------------------------------------------------------------------

    # Normalize a level name or number to a symbol, raising if it's not valid.
    #
    # Relies on Semantic Logger's "internal" {SemanticLogger.level_to_index}
    # method.
    #
    # @see https://github.com/rocketjob/semantic_logger/blob/97247126de32e6ecbf74cbccaa3b3732768d52c5/lib/semantic_logger/semantic_logger.rb#L454
    #
    # @param [Symbol | String | Integer] level
    #   Representation of a level in one of the following formats:
    #
    #   1.  {Symbol} - verified as member of {SemanticLogger::LEVELS} and
    #       returned.
    #
    #   2.  {String} - accepts string representations of the level symbols,
    #       case insensitive.
    #
    #   3.  {Integer} - interpreted as a Ruby StdLib Logger / Rails Logger
    #       level, which are **different** than Semantic Logger's!
    #
    # @return [:trace | :debug | :info | :warn | :error | :fatal]
    #   Log level symbol.
    #
    # @raise
    #   When `level` is invalid.
    #
    def self.level_sym_for(level)
      if SemanticLogger::LEVELS.include? level
        level
      else
        SemanticLogger.index_to_level SemanticLogger.level_to_index(level)
      end
    end

    # Global / default log level, which we always normalize to a symbol.
    #
    # @return [:trace | :debug | :info | :warn | :error | :fatal]
    #
    def self.level
      level_sym_for SemanticLogger.default_level
    end

    # Integer level index. Forwards to {SemanticLogger.default_level_index}.
    #
    # @note
    #   There is some funkiness around level indexes that I think/hope I wrote
    #   down somewhere, so use with some caution/research.
    #
    # @return [Fixnum]
    #
    def self.level_index
      SemanticLogger.default_level_index
    end

    # Set the global default log level.
    #
    # @param level  (see .level_sym_for)
    # @return       (see .level_sym_for)
    # @raise        (see .level_sym_for)
    #
    def self.level=(level)
      SemanticLogger.default_level = level_sym_for level
    end

    # Get the current ENV var prefix to use looking for config (when values
    # are not explictly provided).
    #
    # @return [nil]
    #   A prefix has not been sucessfully set, and we couldn't figure one out
    #   from {.application}.
    #
    # @return [false]
    #   Looking for config in ENV has been explicitly disabled.
    #
    # @return [String]
    #   The ENV var name prefix we'll use looking for logging config.
    #
    def self.env_var_prefix
      return @env_var_prefix unless @env_var_prefix.nil?

      return application.to_s.env_varize unless application.nil?

      nil
    end

    # Set the {.env_var_prefix}.
    #
    # @param [String | false] prefix
    #   Value to set the prefix to. `false` disables looking up config in the
    #   ENV.
    #
    #   If anything other than `false` or a {String} that satisfies
    #   {Cmds::Sys::Env.var_name?} is passed a warning will be logged,
    #   the value will be ignored, and `nil` will be returned.
    #
    # @return [nil]
    #   `prefix` was a bad value and the internal variable was not set. A
    #   warning was also logged.
    #
    # @return [String | false]
    #   The value was set to `prefix`.
    #
    def self.env_var_prefix=(prefix)
      unless prefix == false || Cmds::Sys::Env.var_name?(prefix)
        logger.warn \
          'Bad Cmds::Log.env_var_prefix; must `false` or a String matching' +
          "#{Cmds::Sys::Env::VAR_NAME_RE}. Ignoring...",
          value: prefix

        return nil
      end

      @env_var_prefix = prefix
    end

    # Try to find a log level in the ENV.
    #
    # @param [String | false | nil] prefix
    #   The prefix to look under.
    #
    # @return [nil]
    #   We either didn't look or we didn't find.
    #
    # @return [Symbol]
    #   One of {SemanticLogger::LEVELS}, returned because we found a
    #   {Cmds.truthy?} `<prefix>_DEBUG` or `<prefix>_TRACE`.
    #
    # @return [String]
    #   Value found at `<prefix>_LOG_LEVEL`. **Note that this may not be
    #   a valid level - this method does NOT check!**.
    #
    def self.level_from_env(prefix: env_var_prefix)
      # Bail with a `nil` if we can't figure out a prefix (it's `nil`) or
      # looking in the ENV has been disabled (it's `false`).
      return nil unless prefix

      if truthy? ENV["#{prefix}_TRACE"]
        return :trace
      elsif truthy? ENV["#{prefix}_DEBUG"]
        return :debug
      end

      level = ENV["#{prefix}_LOG_LEVEL"]

      return level unless level.nil? || level == ''

      nil
    end

    # @!endgroup Utility Class Methods

    # @!group Setup Class Methods
    # --------------------------------------------------------------------------

    # Setup logging.
    #
    # @param [String | false | nil] env_var_prefix Prefix to ENV var names to look
    #   for logging setup config under, like `<prefix>_LOG_LEVEL`,
    #   `<prefix>_DEBUG` and `<prefix>_TRACE`.
    #
    #   If `nil` (the default), we'll try to use `application` to guess a prefix.
    #
    #   You can disable any ENV lookups by passing `false`.
    #
    # @param [Boolean] sync Enables or disables synchronous logging, where the log
    #   message is processed entirely in the logging thread before the log call
    #   returns.
    #
    #   {SemanticLogger} offloads log formating and writing to a separate thread
    #   in it's standard configuration, an approach presumably aimed at
    #   performance, but one that can be problematic when logging mutable values
    #   that may change between the log call and the log serialization.
    #
    #   See
    #   {file:doc/known_issues_and_gotchas/semantic_logger_and_mutable_values.md
    #     SemanticLogger and Mutable Values}.
    #
    # @return [nil]
    #
    def self.setup!(level: nil,
                    dest: nil,
                    sync: nil,
                    say_hi: :debug,
                    application: nil,
                    env_var_prefix: nil,
                    header: nil,
                    body: nil)

      unless @__mutex__.try_lock
        raise ThreadError, <<~END
          Mutex is already held.

          You should pretty generally NOT have multiple threads trying to
          setup logging at once or re-enter {Cmds::Log.setup}!
        END
      end

      # Wrap around everything to make sure we release the mutex
      begin
        if sync
          require 'semantic_logger/sync'
          SemanticLogger.sync!
        end

        # Setup main appender if needed so that any logging *in here* hopefully
        # has somewhere to go
        setup_appender! dest

        # Set the application, which we may use for the ENV var prefix
        self.application = application unless application.nil?

        # Set the ENV var prefix, if we received one
        self.env_var_prefix = env_var_prefix unless env_var_prefix.nil?

        # If we didn't receive a level, check the ENV
        level = level_from_env if level.nil?

        # If we ended up with a level, try to set it (will only log a warning
        # if it fails, not raise, which could crash things on boot)
        setup_level! level unless level.nil?

        # Setup formatter header and body tokens, if needed
        setup_formatter_tokens! :header, header
        setup_formatter_tokens! :body, body
      ensure
        # Make sure we release the mutex; don't need to hold it for the rest
        @__mutex__.unlock
      end

      # Name the main thread so that `process_info` doesn't look so lame
      setup_main_thread_name!

      # Possibly say hi
      setup_say_hi say_hi, dest, sync

      nil
    rescue Exception => e
      # Suppress errors in favor of a warning

      logger.warn \
        message: 'Error setting up logging',
        payload: {
          args: {
            level: level,
            dest: dest,
            env_var_prefix: env_var_prefix,
            say_hi: say_hi
          }
        },
        exception: e

      nil
    end # .setup!

    # Call {.setup!} with some default keywords that are nice for CLI apps.
    #
    # @param  (see .setup!)
    # @return (see .setup!)
    #
    def self.setup_for_cli! dest: $stderr,
                            sync: true,
                            **kwds
      setup! dest: dest, sync: sync, **kwds
    end # .setup_for_cli!

    # Was the new name, then realized it was dumb and switched back :D
    singleton_class.send :alias_method, :setup_for_CLI!, :setup_for_cli!

    # Call {.setup!} with some default keywords that are nice for interactive
    # session (console/REPL) usage.
    #
    # @param [Boolean] add_main_logger
    #   Define a `logger` method at the top level (global) that gets a logger
    #   for the main object.
    #
    # @param application: (see .setup!)
    # @param dest: (see .setup!)
    # @param header: (see .setup!)
    # @param sync: (see .setup!)
    #
    # @return (see .setup!)
    #
    def self.setup_for_console! add_main_logger: true,
                                application: $0,
                                dest: $stderr,
                                header: { delete: :process_info },
                                sync: true,
                                **kwds
      setup! \
        dest: dest,
        sync: sync,
        header: header,
        application: application,
        **kwds

      return unless add_main_logger

      TOPLEVEL_BINDING.eval <<~END
        def logger
          Cmds::Log[self]
        end
      END
    end # .setup_for_console!

    # Call {.setup!} but provides default for running RSpec tests: sync,
    # write to
    #
    # @param  (see .setup!)
    # @return (see .setup!)
    #
    def self.setup_for_rspec! dest: $stderr,
                              sync: true,
                              header: { delete: :process_info },
                              **kwds
      setup! \
        dest: dest,
        sync: sync,
        header: header,
        **kwds
    end # .setup_for_rspec!

    # @!endgroup Setup Class Methods

    # ************************************************************************

    def self.sync?
      processor.is_a? Cmds::Log::Appender::Sync
    end

    # The current "main" appender (destination), if any.
    #
    # This is just to simplify things in simple cases, you can always still
    # add multiple appenders.
    #
    # @return [SemanticLogger::Subscriber | nil]
    #
    class << self
      attr_reader :appender
    end

    # Short-cut for `.appender.formatter`.
    #
    # @return [nil]
    #   If there is no {.appender}.
    #
    # @return [SemanticLogger::Formatters::Default]
    #   If there is an {.appender}, the appender's `#formatter` attribute.
    #
    def self.formatter
      appender.formatter if appender
    end

    # Is there a header formatter?
    #
    # @return [Boolean]
    #   `true` if there is an {.formatter} and it responds to ':header'.
    #
    #   If it returns `false`, it means there is no {.appender} attached
    #   or it's formatter does not mix in {Cmds::Log::Formatters::Mixin}.
    #
    #   In this case you can't read or write to the header, so {.header=}
    #   won't do anything.
    #
    def self.header?
      formatter && formatter.respond_to?(:header)
    end

    # Calls `.formatter.header` if there is a {.header?}.
    #
    # @see Cmds::Log::Formatters::Mixin#header
    # @param  (see Cmds::Log::Formatters::Mixin#header)
    # @return (see Cmds::Log::Formatters::Mixin#header)
    # @raise  (see Cmds::Log::Formatters::Mixin#header)
    #
    # @return [nil]
    #   If there is no {.appender} or it's formatter doesn't have a header.
    #
    def self.header *tokens
      formatter.header(*tokens) if header?
    end

    def self.header=(tokens)
      return unless header?

      formatter.header = tokens
    end

    def self.body?
      formatter && formatter.respond_to?(:body)
    end

    def self.body *tokens
      formatter.body(*tokens) if body?
    end

    def self.body=(tokens)
      return unless body?

      formatter.body = tokens
    end

    # @!group Setup Helpers
    # ------------------------------------------------------------------------
    #
    # Break-outs from the monstrosity that {#setup!} became. Only called
    # from there, and only *should* be called from there! Hence these methods
    # are all private as well.
    #

    # Try to set the level, logging a warning and returning `nil` if it fails.
    #
    # @param level (see .level=)
    #
    # @return [Symbol]
    #   The level symbol if it was set successfully.
    #
    # @return [nil]
    #   If the set failed (also logs a warning).
    #
    def self.setup_level!(level)
      logger.catch.warn(
        'Unable to set level, probably bad value',
        level: level
      ) do
        self.level = level
      end
    end # .try_set_level

    private_class_method :setup_level!

    # Possibly say hi. Params are from {#setup!}.
    #
    # @private
    # @return [nil]
    #
    def self.setup_say_hi(say_hi, dest, sync)
      will_say_hi = \
        case say_hi
        when true, false
          say_hi
        when Symbol, String, Integer
          logger.catch(on_fail: false).warn(
            'Bad `say_hi` kwd in {Cmds::Log.setup}',
            say_hi: say_hi,
            expected: 'Symbol, String, or Fixnum representing log level'
          ) do
            level_index < SemanticLogger.level_to_index(say_hi)
          end

        else
          logger.warn 'Bad `say_hi` kwd in {Cmds::Log.setup}',
                      say_hi: say_hi,
                      expected: [true, false, Symbol, String, Integer]

          false
        end

      if will_say_hi
        loggable_dest = \
          case dest
          when Hash
            dest.map { |k, v| [k, v.to_s.truncate(42)] }.to_h
          else
            dest.to_s.truncate 42
          end

        logger.info 'Hi! Logging is setup',
                    level: level,
                    dest: loggable_dest,
                    sync: sync
      end

      nil
    end # .setup_say_hi

    private_class_method :setup_say_hi

    # Make sure the main thread has a {Thread#name} (a core_ext added by
    # SemanticLogger).
    #
    # We do this so that the `process_info` section in log messages isn't so
    # distracting and useless ({Thread#name} defaults to the thread's
    # `#object_id`).
    #
    # If it has no name, we name it "main".
    #
    # @private
    # @return [nil]
    #
    def self.setup_main_thread_name!
      main = Thread.main
      main.name = 'main' unless main.instance_variable_defined? :@name
      nil
    end # .name_main_thread

    private_class_method :setup_main_thread_name!

    # Setup formatter tokens for the {#header} or {#body}.
    #
    # @private
    #
    # @param [:header | :body] name
    #   What formatter tokens we're setting up.
    #
    # @return [nil]
    #
    def self.setup_formatter_tokens!(name, arg)
      # Bail out on `nil`
      return nil if arg.nil?

      # `self.header` or `self.body`
      target = send name

      # Bail out if we don't have it
      return nil if target.nil?

      case arg
      when Array
        # It's an array, just set it through the forwarder method
        send "#{name}=", arg
      when Hash
        # It's a hash, so look for a `:delete` or `:remove` key, and delete
        # each of those from the target
        Array(arg.fetch(:delete, arg[:remove]))
          .each { |token| target.delete token.try(:to_sym) }
      end

      nil
    end # .setup_formatter_tokens!

    private_class_method :setup_formatter_tokens!

    # @param [SemanticLogger::Subscriber | Hash | String | Pathname | IO] dest
    #   Where to log with the "main" appender (what goes in {#appender}).
    #
    def self.setup_appender!(dest)
      # Bail out if nothing to do
      return nil if dest.nil?

      # Save ref to current appender (if any) so we can remove it after adding
      # the new one.
      old_appender = @appender

      @appender = \
        case dest
        when false
          # Used to remove the appender and set {.appender} to `nil`.
          nil

        when SemanticLogger::Subscriber
          # Can be handled directly
          SemanticLogger.add_appender dest

        when Hash
          # Override color formatter with our own implementation
          dest = dest.merge formatter: Cmds::Log::Formatters::Color.new if dest[:formatter] == :color

          SemanticLogger.add_appender dest

        when String, Pathname
          # Assume these are file paths
          SemanticLogger.add_appender file_name: dest.to_s

        when IO
          SemanticLogger.add_appender \
            io: dest,
            formatter: Cmds::Log::Formatters::Color.new

        else
          # I guess just try and add it...?
          SemanticLogger.add_appender dest

        end

      # Remove the old appender (if there was one). This is done after adding
      # the new one so that failing won't result with no appenders.
      SemanticLogger.remove_appender(old_appender) if old_appender

      @appender
    end

    private_class_method :setup_appender!

    # @!endgroup Setup Helpers
  end # module Log
end # class Cmds
