# util functions

# stdlib
require 'shellwords'

require 'cmds/util/tokenize_options'

module Cmds
  # class methods
  # =============

  # shortcut for Shellwords.escape
  # 
  # also makes it easier to change or customize or whatever
  def self.esc str
    Shellwords.escape str
  end  

  # expand one of the substitutions
  def self.expand_sub sub
    case sub
    when nil
      # nil is just an empty string, NOT an empty string bash token
      ''
    when Hash
      tokenize_options sub
    else
      esc sub.to_s
    end
  end # ::expand_sub
  
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
        /(?<=\A|[[:space:]])\%s(?=\Z|[[:space:]])/,
        '<%= arg %>'
      )
      .gsub(
        # %%s => %s (escpaing)
        /(?<=\A|[[:space:]])(\%+)\%s(?=\Z|[[:space:]])/,
        '\1s'
      )
      .gsub(
        # %{key} => <%= key %>, %{key?} => <%= key? %>
        /(?<=\A|[[:space:]])\%\{([a-zA-Z_]+\??)\}(?=\Z|[[:space:]])/,
        '<%= \1 %>'
      )
      .gsub(
        # %%{key} => %{key}, %%{key?} => %{key?} (escpaing)
        /(?<=\A|[[:space:]])(\%+)\%\{([a-zA-Z_]+\??)\}(?=\Z|[[:space:]])/,
        '\1{\2}\3'
      )
      .gsub(
        # %<key>s => <%= key %>, %<key?>s => <%= key? %>
        /(?<=\A|[[:space:]])\%\<([a-zA-Z_]+\??)\>s(?=\Z|[[:space:]])/,
        '<%= \1 %>'
      )
      .gsub(
        # %%<key>s => %<key>s, %%<key?>s => %<key?>s (escaping)
        /(?<=\A|[[:space:]])(\%+)\%\<([a-zA-Z_]+\??)\>s(?=\Z|[[:space:]])/,
        '\1<\2>s'
      )
  end # ::replace_shortcuts
  
end # module Cmds
