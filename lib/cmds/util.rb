# util functions

# stdlib
require 'shellwords'

# package
require 'cmds/util/shell_escape'
require 'cmds/util/tokenize_options'
require 'cmds/util/text'

class Cmds
  # class methods
  # =============

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

  # tokenize values for the shell. each values is tokenized individually
  # and the results are joined with a space.
  #
  # @param [Array<Object>] *values
  #   values to tokenize.
  #
  # @return [String]
  #   tokenized string ready for the shell.
  #
  def self.tokenize *values, **opts
    values.map do |value|
      case value
      when Hash
        tokenize_options value, **opts
      else
        tokenize_value value, **opts
      end
    end.flatten.join ' '
  end # .tokenize

  # Formats a command string.
  #
  # @param [String] string
  #   Command string to format.
  #
  # @param [nil, :squish, :pretty, #call] with
  #   How to format the command string.
  #
  def self.format(string, with = :squish)
    case with
    when nil
      string

    when :squish
      Text.squish string

    when :pretty
      pretty_format string

    else
      with.call string
    end
  end # .format

  def self.pretty_format(string)
    string = string.gsub(/\n(\s*\n)+\n/, "\n\n")

    string.lines.map do |line|
      line = line.rstrip

      if line.end_with? '\\'
        line
      elsif line == ''
        nil
      elsif line =~ /\s$/
        line + '\\'
      else
        line + ' \\'
      end
    end.reject { |x| x.nil? }.join("\n")
  end

  # raise an error unless the exit status is 0.
  #
  # @param [String] cmd
  #   the command sting that was executed.
  #
  # @param [Fixnum] status
  #   the command's exit status.
  #
  # @return [nil]
  #
  # @raise [SystemCallError]
  #   if exit status is not 0.
  #
  def self.check_status(cmd, status, err = nil)
    return if status.equal? 0

    msg = Text.squish "command `#{cmd}` exited with status #{status}"

    msg += " and stderr:\n\n" + err if err

    # Remove NULL bytes (not sure how they get in there...)
    msg = msg.delete("\000")

    raise SystemCallError.new msg, status
  end # .assert
end # class Cmds
