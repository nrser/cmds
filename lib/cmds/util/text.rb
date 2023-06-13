require 'cmds/refine'

using Cmds::Refine

class Cmds
  module Text
    # @!group Text Functions

    # Constants
    # =====================================================================

    INDENT_RE = /\A[\ \t]*/

    INDENT_TAG_MARKER     = "\x1E"
    INDENT_TAG_SEPARATOR  = "\x1F"

    # Regular expression used to match whitespace.
    #
    # @return [Regexp]
    #
    WHITESPACE_RE = /\A[[:space:]]*\z/

    # Functions
    # =====================================================================

    def self.whitespace?(string)
      string =~ WHITESPACE_RE
    end

    def self.find_indent(text)
      common_prefix(lines(text).map { |line| line[INDENT_RE] })
    end

    def self.indented?(text)
      !find_indent(text).empty?
    end

    # adapted from active_support 4.2.0
    #
    # <https://github.com/rails/rails/blob/7847a19f476fb9bee287681586d872ea43785e53/activesupport/lib/active_support/core_ext/string/indent.rb>
    #
    def self.indent(text,
                    amount = 2,
                    indent_string: nil,
                    indent_empty_lines: false,
                    skip_first_line: false)
      if skip_first_line
        lines = self.lines text

        lines.first + indent(
          rest(lines).join,
          amount,
          indent_string: indent_string,
          skip_first_line: false
        )

      else
        indent_string = indent_string || text[/^[ \t]/] || ' '
        re = indent_empty_lines ? /^/ : /^(?!$)/
        text.gsub re, indent_string * amount

      end
    end

    def self.dedent(text,
                    ignore_whitespace_lines: true,
                    return_lines: false)
      return text if text.empty?

      all_lines = if text.is_a?(Array)
                    text
                  else
                    text.lines
                  end

      indent_significant_lines = if ignore_whitespace_lines
                                   all_lines.reject { |line| whitespace? line }
                                 else
                                   all_lines
                                 end

      indent = find_indent indent_significant_lines

      return text if indent.empty?

      dedented_lines = all_lines.map do |line|
        if line.start_with? indent
          line[indent.length..-1]
        elsif line.end_with? "\n"
          "\n"
        else
          ''
        end
      end

      if return_lines
        dedented_lines
      else
        dedented_lines.join
      end
    end # .dedent

    # I like dedent better, but other libs seems to call it deindent
    singleton_class.send :alias_method, :deindent, :dedent

    # Tag each line of `text` with special marker characters around it's leading
    # indent so that the resulting text string can be fed through an
    # interpolation process like ERB that may inject multiline strings and the
    # result can then be fed through {indent_untag} to apply the correct
    # indentation to the interpolated lines.
    #
    # Each line of `text` is re-formatted like:
    #
    #     "<marker><leading_indent><separator><line_without_leading_indent>"
    #
    # `marker` and `separator` can be configured via keyword arguments, but they
    #  default to:
    #
    # -   `marker` - {NRSER::INDENT_TAG_MARKER}, the no-printable ASCII
    #     *record separator* (ASCII character 30, "\x1E" / "\u001E").
    #
    # -   `separator` - {NRSER::INDENT_TAG_SEPARATOR}, the non-printable ASCII
    #     *unit separator* (ASCII character 31, "\x1F" / "\u001F")
    #
    # @example With default marker and separator
    #   indent_tag "    hey there!"
    #   # => "\x1E    \x1Fhey there!"
    #
    # @param [String] text
    #   String text to indent tag.
    #
    # @param [String] marker
    #   Special string to mark the start of tagged lines. If interpolated text
    #   lines start with this string you're going to have a bad time.
    #
    # @param [String] separator
    #   Special string to separate the leading indent from the rest of the line.
    #
    # @return [String]
    #   Tagged text.
    #
    def self.indent_tag(text,
                        marker: INDENT_TAG_MARKER,
                        separator: INDENT_TAG_SEPARATOR)
      text.lines.map do |line|
        indent = if match = INDENT_RE.match(line)
                   match[0]
                 else
                   ''
                 end

        "#{marker}#{indent}#{separator}#{line[indent.length..-1]}"
      end.join
    end # .indent_tag

    # Reverse indent tagging that was done via {indent_tag}, indenting
    # any untagged lines to the same level as the one above them.
    #
    # @param [String] text
    #   Tagged text string.
    #
    # @param [String] marker
    #   Must be the marker used to tag the text.
    #
    # @param [String] separator
    #   Must be the separator used to tag the text.
    #
    # @return [String]
    #   Final text with interpolation and indent correction.
    #
    def self.indent_untag(text,
                          marker: INDENT_TAG_MARKER,
                          separator: INDENT_TAG_SEPARATOR)

      current_indent = ''

      text.lines.map do |line|
        current_indent, line = line[marker.length..-1].split(separator, 2) if line.start_with? marker

        current_indent + line
      end.join
    end # .indent_untag

    # Indent tag a some text via {indent_tag}, call the block with it,
    # then pass the result through {indent_untag} and return that.
    #
    # @param [String] marker
    #   Special string to mark the start of tagged lines. If interpolated text
    #   lines start with this string you're going to have a bad time.
    #
    # @param [String] separator
    #   Must be the separator used to tag the text.
    #
    # @return [String]
    #   Final text with interpolation and indent correction.
    #
    def self.with_indent_tagged(text,
                                marker: INDENT_TAG_MARKER,
                                separator: INDENT_TAG_SEPARATOR,
                                &interpolate_block)
      indent_untag(
        interpolate_block.call(
          indent_tag(text, marker: marker, separator: separator)
        ),
        marker: marker,
        separator: separator
      )
    end # .with_indent_tagged

    # @todo document Lines class.
    class Lines < Array
      # Instantiate a new `Lines`.
      def initialize
      end # #initialize
    end # class Lines

    # Functions
    # =====================================================================

    def self.lines(text)
      case text
      when String
        text.lines
      when Array
        text
      else
        raise TypeError,
              "Expected String or Array, found #{text.class.safe_name}"
      end
    end

    # turn a multi-line string into a single line, collapsing whitespace
    # to a single space.
    #
    # same as ActiveSupport's String.squish, adapted from there.
    def self.squish(str)
      str.gsub(/[[:space:]]+/, ' ').strip
    end # squish

    singleton_class.send :alias_method, :unblock, :squish

    def self.common_prefix(strings)
      raise ArgumentError, "argument can't be empty" if strings.empty?

      sorted = strings.sort

      i = 0

      while sorted.first[i] == sorted.last[i] &&
            i < [sorted.first.length, sorted.last.length].min
        i += 1
      end

      sorted.first[0...i]
    end # .common_prefix
  end # module Text
end # class Cmds
