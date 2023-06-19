class Cmds
  # @!group Shell Escaping Constants
  # ======================================================================

  # Quote "name" keys `:single` and `:double` mapped to their character.
  #
  # @return [Hash<Symbol, String>]
  #
  QUOTE_TYPES = {
    single: %('),
    double: %(")
  }.freeze

  # List containing just `'` and `"`.
  #
  # @return [Array<String>]
  #
  QUOTE_VALUES = QUOTE_TYPES.values.freeze

  # @!group Shell Escaping Class Methods
  # ======================================================================

  # Shortcut for Shellwords.escape
  #
  # Also makes it easier to change or customize or whatever.
  #
  # @see http://ruby-doc.org/stdlib/libdoc/shellwords/rdoc/Shellwords.html#method-c-escape
  #
  # @param [#to_s] str
  # @return [String]
  #
  def self.esc(str)
    Shellwords.escape str
  end

  # Format a string to be a shell token by wrapping it in either single or
  # double quotes and replacing instances of that quote with what I'm calling
  # a "quote dance":
  #
  # 1.  Closing the type of quote in use
  # 2.  Quoting the type of quote in use with the *other* type of quote
  # 3.  Then opening up the type in use again and keeping going.
  #
  # @example Single quoting string containing single quotes
  #
  #   Cmds.quote_dance %{you're}, :single
  #   # => %{'you'"'"'re'}
  #
  # @example Double quoting string containing double quotes
  #
  #   Cmds.quote_dance %{hey "ho" let's go}, :double
  #   # => %{"hey "'"'"ho"'"'" let's go"}
  #
  # **_WARNING:
  #     Does NOT escape anything except the quotes! So if you double-quote a
  #      string with shell-expansion terms in it and pass it to the shell
  #     THEY WILL BE EVALUATED_**
  #
  # @param [String] string
  #   String to quote.
  #
  # @return [String]
  #   Quoted string.
  #
  def self.quote_dance(string, quote_type)
    outside = QUOTE_TYPES.fetch quote_type
    inside = QUOTE_VALUES[QUOTE_VALUES[0] == outside ? 1 : 0]

    outside +
      string.gsub(
        outside,
        outside + inside + outside + inside + outside
      ) +
      outside
  end # .quote_dance

  # Quote a string for use in the shell. Uses single quotes.
  #
  # @param [String] string
  #   String to quote.
  #
  # @return [String]
  #   Single-quoted string.
  #
  def self.quote(string)
    quote_dance string, :single
  end
end # class Cmds
