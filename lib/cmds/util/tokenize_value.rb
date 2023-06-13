require 'json'

require 'cmds/refine/binding'
require_relative 'defaults'

using Cmds::Refine

class Cmds
  TOKENIZE_OPT_KEYS = %i[
    array_mode
    array_join_string
    dash_opt_names
    false_mode
    flatten_array_values
    hash_mode
    hash_join_string
    long_opt_separator
    short_opt_separator
  ].freeze

  # turn an option name and value into an array of shell-escaped string
  # token suitable for use in a command.
  #
  # @param [String] name
  #   string name (one or more characters).
  #
  # @param [*] value
  #   value of the option.
  #
  # @param [Hash] **opts
  # @option [Symbol] :array_mode (:multiple)
  #   one of:
  #
  #   1.  `:multiple` (default) provide one token for each value.
  #
  #           expand_option 'blah', [1, 2, 3]
  #           => ['--blah=1', '--blah=2', '--blah=3']
  #
  #   2.  `:join` -- join values in one token.
  #
  #           expand_option 'blah', [1, 2, 3], array_mode: :join
  #           => ['--blah=1,2,3']
  #
  # @option [String] :array_join_string (',')
  #   string to join array values with when `:array_mode` is `:join`.
  #
  # @return [Array<String>]
  #   List of individual shell token strings.
  #
  # @raise [ArgumentError]
  #   If options are set to bad values.
  #
  def self.tokenize_value value, **opts
    opts = defaults opts, TOKENIZE_OPT_KEYS

    case value
    when nil
      # `nil` values produces no tokens
      []

    when Array
      # The PITA one...
      #
      # May produce one or multiple tokens.
      #

      # Flatten the array value if option is set
      value = value.flatten if opts[:flatten_array_values]

      case opts[:array_mode]
      when :repeat
        # Encode each entry as it's own token
        #
        # [1, 2, 3] => ["1", "2", "3"]
        #

        # Pass entries back through for individual tokenization and flatten
        # so we are sure to return a single-depth array
        value.map { |entry| tokenize_value entry, **opts }.flatten

      when :join
        # Encode all entries as one joined string token
        #
        # [1, 2, 3] => ["1,2,3"]
        #

        [esc(value.join(opts[:array_join_string]))]

      when :json
        # Encode JSON dump as single token, single-quoted
        #
        # [1, 2, 3] => ["'[1,2,3]'"]

        [single_quote(JSON.dump(value))]

      else
        # SOL
        raise ArgumentError, binding.erb(
          <<~EOS
            Bad `:array_mode` option:

                <%= opts[:array_mode].pretty_inspect %>

            Should be :join, :repeat or :json

          EOS
        )

      end # case opts[:array_mode]

    when Hash
      # Much the same as array
      #
      # May produce one or multiple tokens.
      #

      case opts[:hash_mode]
      when :join
        # Join the key and value using the option and pass the resulting array
        # back through to be handled as configured
        tokenize_value \
          value.map { |k, v| [k, v].join opts[:hash_join_string] },
          **opts

      when :json
        # Encode JSON dump as single token, single-quoted
        #
        # [1, 2, 3] => [%{'{"a":1,"b":2,"c":3}'}]

        [single_quote(JSON.dump(value))]

      else
        # SOL
        raise ArgumentError, binding.erb(
          <<~EOS
            Bad `:hash_mode` option:

                <%= opts[:hash_mode].pretty_inspect %>

            Should be :join, or :json

          EOS
        )
      end

    else
      # We let {Cmds.esc} handle it, and return that as a single token
      [esc(value)]

    end
  end
end
