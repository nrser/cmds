# util functions

# stdlib
require 'shellwords'

# deps
require 'nrser'

# package
require 'cmds/util/tokenize_options'

using NRSER

class Cmds
  # class methods
  # =============

  # shortcut for Shellwords.escape
  # 
  # also makes it easier to change or customize or whatever
  def self.esc str
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
  def self.tokenize *values
    values.map {|value|
      case value
      when nil
        # nil is just an empty string, NOT an empty string bash token
        ''
      when Hash
        tokenize_options value
      else
        esc value.to_s
      end
    }.join ' '
  end # ::tokenize
  
  # formats a command string 
  def self.format string, with = :squish
    case with
    when :squish
      NRSER.squish string
      
    when :pretty
      pretty_format string
    
    else
      with.call string
    end
  end
  
  def self.pretty_format string
    string = string.gsub(/\n(\s*\n)+\n/, "\n\n")
    
    string.lines.map {|line|
      line = line.rstrip
      
      if line.end_with? '\\'
        line
      elsif line == ''
        '\\'
      elsif line =~ /\s$/
        line + '\\'
      else
        line + ' \\'
      end
    }.join("\n")
  end

  def self.replace_shortcuts template
    template
      .gsub(
        # %s => <%= arg %>
        /(?<=\A|\=|[[:space:]])\%s(?=\Z|[[:space:]])/,
        '<%= arg %>'
      )
      .gsub(
        # %%s => %s (escaping)
        /(?<=\A|[[:space:]])(\%+)\%s(?=\Z|[[:space:]])/,
        '\1s'
      )
      .gsub(
        # %{key} => <%= key %>, %{key?} => <%= key? %>
        /(?<=\A|\=|[[:space:]])\%\{([a-zA-Z_]+\??)\}(?=\Z|[[:space:]])/,
        '<%= \1 %>'
      )
      .gsub(
        # %%{key} => %{key}, %%{key?} => %{key?} (escaping)
        /(?<=\A|[[:space:]])(\%+)\%\{([a-zA-Z_]+\??)\}(?=\Z|[[:space:]])/,
        '\1{\2}\3'
      )
      .gsub(
        # %<key>s => <%= key %>, %<key?>s => <%= key? %>
        /(?<=\A|\=|[[:space:]])\%\<([a-zA-Z_]+\??)\>s(?=\Z|[[:space:]])/,
        '<%= \1 %>'
      )
      .gsub(
        # %%<key>s => %<key>s, %%<key?>s => %<key?>s (escaping)
        /(?<=\A|[[:space:]])(\%+)\%\<([a-zA-Z_]+\??)\>s(?=\Z|[[:space:]])/,
        '\1<\2>s'
      )
  end # ::replace_shortcuts
  
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
  def self.check_status cmd, status, err = nil
    unless status.equal? 0
      msg = NRSER.squish <<-END
        command `#{ cmd }` exited with status #{ status }
      END
      
      if err
        msg += " and stderr:\n\n" + err
      end
      
      raise SystemCallError.new msg, status
    end
  end # .assert
end # class Cmds
