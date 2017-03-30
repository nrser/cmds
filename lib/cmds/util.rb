# util functions

require 'shellwords'

require_relative 'util/tokenize_options'

class Cmds
  # class methods
  # =============

  # shortcut for Shellwords.escape
  # 
  # also makes it easier to change or customize or whatever
  def self.esc str
    Shellwords.escape str
  end

  # escape option hash.
  #
  # this is only useful for the two common option styles: 
  #
  # -   single character keys become `-<char> <value>`
  #
  #         {x: 1}    => "-x 1"
  # 
  # -   longer keys become `--<key>=<value>` options
  # 
  #         {blah: 2} => "--blah=2"
  #
  # if you have something else, you're going to have to just put it in
  # the cmd itself, like:
  # 
  #     Cmds "blah -assholeOptionOn:%{s}", "ok"
  # 
  # or whatever similar shit said command requires.
  #
  # however, if the value is an Array, it will repeat the option for each
  # value:
  # 
  #     {x:     [1, 2, 3]} => "-x 1 -x 2 -x 3"
  #     {blah:  [1, 2, 3]} => "--blah=1 --blah=2 --blah=3"
  # 
  # i can't think of any right now, but i swear i've seen commands that take
  # opts that way.
  # 
  def self.expand_option_hash hash, opts = {}
    opts = {
      array_mode: :csv,
    }.merge opts
    
    hash.map {|key, values|
      # keys need to be strings
      key = key.to_s unless key.is_a? String

      [key, values]

    }.sort {|(key_a, values_a), (key_b, values_b)|
      # sort by the (now string) keys
      key_a <=> key_b

    }.map {|key, values|
      # for simplicity's sake, treat all values like an array
      values = [values] unless values.is_a? Array

      # keys of length 1 expand to `-x v` form
      expanded = if key.length == 1
        values.map {|value|
          if value.nil?
            "-#{ esc key }"
          else
            "-#{ esc key } #{ esc value}"
          end
        }

      # longer keys expand to `--key=value` form
      else
        values.map {|value|
          if value.nil?
            "--#{ esc key }"
          else
            "--#{ esc key }=#{ esc value }"
          end
        }
      end
    }.flatten.join ' '
  end # ::expand_option_hash
  
  

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

  # substitute values into a command template, escaping them for the shell and
  # offering convenient expansions for some structures. uses ERB templating,
  # so logic is supported as well.
  # 
  # check out the {file:README.md#substitutions README} for details on use.
  # 
  # @param template [String] command template with token to be replaced /
  #     expanded / escaped.
  # 
  # @param args [Array] positional substitutions for occurances of
  #     - `<%= arg %>`
  #     - `%s`
  #     
  #     tokens in the `template` parameter.
  # 
  # @param kwds [Hash] keyword subsitutions for occurances of the form
  #     
  #     - `<%= key %>`
  #     - `%{key}`
  #     - `%<key>s`
  #     
  #     as well as optional
  # 
  #     - `<%= key? %>`
  #     - `%{key?}`
  #     - `%<key?>s`
  #     
  #     tokens in the `template` parameter (where `key` is replaced with the
  #     symbol name in the hash).
  #
  # @return [String] formated command string suitable for execution.
  # 
  # @raise [TypeError] if `args` is not an {Array}.
  # @raise [TypeError] if `kwds` is not a {Hash}.
  # 
  def self.sub template, args = [], kwds = {}
    raise TypeError.new("args must be an Array") unless args.is_a? Array
    raise TypeError.new("kwds must be an Hash") unless kwds.is_a? Hash

    context = ERBContext.new(args, kwds)
    erb = ShellEruby.new replace_shortcuts(template)

    erb.result(context.get_binding)
  end # ::sub
  
  # substitute parameters into `@template`.
  # 
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # 
  # @return [String]
  #   the prepared command string.
  # 
  def sub *args, **kwds
    context = ERBContext.new((@args + args), @kwds.merge(kwds))
    erb = ShellEruby.new self.class.replace_shortcuts(@template)

    erb.result(context.get_binding)
  end
  
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
    string.lines.map {|line|
      line = line.rstrip
      
      if line.end_with? '\\'
        line
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

  # instance methods
  # ================

  # returns a new `Cmds` with the subs and input block merged in
  def curry *args, **kwds, &input_block
    self.class.new @template, {
      args: (@args + args),
      kwds: (@kwds.merge kwds),
      input: (input || @input),
    }
  end
  
  # prepare a shell-safe command string for execution.
  # 
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # 
  # @return [String]
  #   the prepared command string.
  # 
  def prepare *args, **kwds
    self.class.format sub(*args, **kwds), @format
  end
  
  def to_s
    prepare
  end

  private

    # merges options already present on the object with options
    # provided via subs and input_block and returns a new options
    # Hash
    def merge_options subs, input_block
      # get the options present in the arguments
      options = Cmds.options subs, input_block
      # the new args are created by appending the provided args to the
      # existing ones
      options[:args] = @args + options[:args]
      # the new kwds are created by merging the provided kwds into the
      # existing ones (new values override previous)
      options[:kwds] = @kwds.merge options[:kwds]
      # if there is input present via the provided block, it is used.
      # otherwise, previous input is used, which may be `nil`
      options[:input] ||= @input
      return options
    end # #merge_options

  # end private
end # class Cmds
