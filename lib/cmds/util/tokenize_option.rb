require 'json'

require 'cmds/refine'
require_relative 'defaults'
require_relative 'tokenize_value'

using Cmds::Refine

class Cmds
  # Turn an option name and value into an array of shell-escaped string
  # tokens suitable for use in a command.
  #
  # @param [String] name
  #   String name (one or more characters).
  #
  # @param [*] value
  #   Value of the option.
  #
  # @param [Hash] **opts
  #
  # @option [Symbol] :array_mode (:join)
  #   one of:
  #
  #   1.  `:join` (default) -- join values in one token.
  #
  #           tokenize_option 'blah', [1, 2, 3], array_mode: :join
  #           => ['--blah=1,2,3']
  #
  #   2.  `:repeat` repeat the option for each value.
  #
  #           tokenize_option 'blah', [1, 2, 3], array_mode: :repeat
  #           => ['--blah=1', '--blah=2', '--blah=3']
  #
  # @option [String] :array_join_string (',')
  #   String to join array values with when `:array_mode` is `:join`.
  #
  # @return [Array<String>]
  #   List of individual shell token strings, escaped for use.
  #
  # @raise [ArgumentError]
  #   1.  If `name` is the wrong type or empty.
  #   2.  If any options have bad values.
  #
  def self.tokenize_option name, value, **opts
    # Set defaults for any options not passed
    opts = defaults opts, TOKENIZE_OPT_KEYS

    # Validate `name`
    unless name.is_a?(String) && name.length > 0
      raise ArgumentError, Text.squish(
        %(`name` must be a String of length greater than zero,
          found #{name.inspect})
      )
    end

    name = name.gsub('_', '-') if opts[:dash_opt_names]

    # Set type (`:short` or `:long`) prefix and name/value separator depending
    # on if name is "short" (single character) or "long" (anything else)
    #
    type, prefix, separator = \
      if name.length == 1
        # -b <value> style (short)
        [:short, '-', opts[:short_opt_separator]]
      else
        # --blah=<value> style (long)
        [:long, '--', opts[:long_opt_separator]]
      end

    case value

    # Special cases (booleans), where we may want to emit an option name but
    # no value (depending on options)
    #
    when true
      # `-b` or `--blah` style token
      [prefix + esc(name)]

    when false
      case opts[:false_mode]
      when :omit, :ignore
        # Don't emit any token for a false boolean
        []

      when :negate, :no
        # Emit `--no-blah` style token
        #
        if type == :long
          # Easy one
          ["--no-#{esc(name)}"]

        else
          # Short option... there seems to be little general consensus on how
          # to handle these guys; I feel like the most common is to invert the
          # case, which only makes sense for languages that have lower and
          # upper case :/
          case opts[:false_short_opt_mode]

          when :capitalize, :cap, :upper, :upcase
            # Capitalize the name
            #
            # {x: false} => ["-X"]
            #
            # This only really makes sense for lower case a-z, so raise if it's
            # not in there
            unless 'a' <= name && name <= 'z'
              raise ArgumentError, binding.erb(
                <<~EOS
                  Can't negate CLI option '<%= name %>' by capitalizing name.

                  Trying to tokenize option '<%= name %>' with `false` value and:

                  1.  `:false_mode` is set to `<%= opts[:false_mode] %>`, which
                      tells {Cmds.tokenize_option} to emit a "negating" name with
                      no value like

                          {update: false} => --no-update

                  2.  `:false_short_opt_mode` is set to `<%= opts[:false_short_opt_mode] %>`,
                      which means negate through capitalizing the name character,
                      like:

                          {u: false} => -U

                  3.  But this is only implemented for length 1 names in [a-z]

                  Either change the {Cmds} instance configuration or provide a
                  different CLI option name or value.
                EOS
              )
            end

            # Emit {x: false} => ['-X'] style
            ["-#{name.upcase}"]

          when :long
            # Treat it the same as a long option,
            # emit {x: false} => ['--no-x'] style
            #
            # Yeah, I've never seen it anywhere else, but it seems reasonable I
            # guess..?
            #
            ["--no-#{esc(name)}"]

          when :string
            # Use the string 'false' as a value
            [prefix + esc(name) + separator + 'false']

          when String
            # It's some custom string to use
            [prefix + esc(name) + separator + esc(string)]

          else
            raise ArgumentError, binding.erb(
              <<~EOS
                Bad `:false_short_opt_mode` value:

                    <%= opts[:false_short_opt_mode].pretty_inspect %>

                Should be

                1.  :capitalize (or :cap, :upper, :upcase)
                2.  :long
                3.  :string
                4.  any String

              EOS
            )

          end # case opts[:false_short_opt_mode]
        end # if :long else
      else
        raise ArgumentError, Text.squish(
          %(bad :false_mode option: #{opts[:false_mode]}, should be :omit or :no)
        )
      end

    # General case
    else
      # Tokenize the value, which may
      #
      # 1.  Result in more than one token, like when `:array_mode` is `:repeat`
      #     (in which case we want to emit multiple option tokens)
      #
      # 2.  Result in zero tokens, like when `value` is `nil`
      #     (in which case we want to emit no option tokens)
      #
      # and map the resulting tokens into option tokens
      #
      tokenize_value(value, **opts).map do |token|
        prefix + esc(name) + separator + token
      end

    end # case value
  end # .tokenize_option
end # class Cmds
