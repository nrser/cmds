# util functions
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
  def self.expand_option_hash hash
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
      expand_option_hash sub
    else
      esc sub.to_s
    end
  end # ::expand_sub

  # substitute values into a command, escaping them for the shell and
  # offering convenient expansions for some structures.
  # 
  # `cmd` is a string that can be substituted via ruby's `%` operator, like
  # 
  #     "git diff %s"
  # 
  # for positional substitution, or 
  # 
  #     "git diff %{path}"
  # 
  # for keyword substitution.
  # 
  # `subs` is either:
  # 
  # -   an Array when `cmd` has positional placeholders
  # -   a Hash when `cmd` has keyword placeholders.
  # 
  # the elements of the `subs` array or values of the `subs` hash are:
  # 
  # -   strings that are substituted into `cmd` after being escaped:
  #     
  #         sub "git diff %{path}", path: "some path/to somewhere"
  #         # => 'git diff some\ path/to\ somewhere'
  # 
  # -   hashes that are expanded into options:
  #     
  #         sub "psql %{opts} %{database} < %{filepath}",
  #           database: "blah",
  #           filepath: "/where ever/it/is.psql",
  #           opts: {
  #             username: "bingo bob",
  #             host: "localhost",
  #             port: 12345,
  #           }
  #         # => 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  # 
  def self.sub cmd, args = [], kwds = {}
    raise TypeError.new("args must be an Array") unless args.is_a? Array
    raise TypeError.new("kwds must be an Hash") unless kwds.is_a? Hash

    context = ERBContext.new(args, kwds)
    erb = ShellEruby.new(replace_shortcuts cmd)

    NRSER.squish erb.result(context.get_binding)
  end # ::sub

  def self.options subs, input_block
    args = []
    kwds = {}
    input = input_block.nil? ? nil : input_block.call

    case subs.length
    when 0
      # nothing to do
    when 1
      # can either be a hash, which is interpreted as a keywords,
      # or an array, which is interpreted as positional arguments
      case subs[0]
      when Hash
        kwds = subs[0]

      when Array
        args = subs[0]

      else
        raise TypeError.new NRSER.squish <<-BLOCK
          first *subs arg must be Array or Hash, not #{ subs[0].inspect }
        BLOCK
      end

    when 2
      # first arg needs to be an array, second a hash
      unless subs[0].is_a? Array
        raise TypeError.new NRSER.squish <<-BLOCK
          first *subs arg needs to be an array, not #{ subs[0].inspect }
        BLOCK
      end

      unless subs[1].is_a? Hash
        raise TypeError.new NRSER.squish <<-BLOCK
          second *subs arg needs to be a Hash, not #{ subs[1].inspect }
        BLOCK
      end

      args, kwds = subs
    else
      raise ArgumentError.new NRSER.squish <<-BLOCK
        must provide one or two *subs arguments, received #{ 1 + subs.length }
      BLOCK
    end

    return {
      args: args,
      kwds: kwds,
      input: input,
    }
  end # ::options

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
  def curry *subs, &input_block
    self.class.new @template, merge_options(subs, input_block)
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
      # exising ones (new values override previous)
      options[:kwds] = @kwds.merge options[:kwds]
      # if there is input present via the provided block, it is used.
      # otherwise, previous input is used, which may be `nil`
      options[:input] ||= @input
      return options
    end # #merge_options

  # end private
end # class Cmds
