require 'shellwords'

require "cmds/version"

class Cmds
  # class Result
  #   attr_reader :cmd, :status, :out, :err

  #   def ok?
  #     @status == 0
  #   end

  #   def error?
  #     ! ok?
  #   end
  # end

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
            "-#{ Shellwords.escape key }"
          else
            "-#{ Shellwords.escape key } #{ Shellwords.escape value}"
          end
        }

      # longer keys expand to `--key=value` form
      else
        values.map {|value|
          if value.nil?
            "--#{ Shellwords.escape key }"
          else
            "--#{ Shellwords.escape key }=#{ Shellwords.escape value }"
          end
        }
      end
    }.flatten.join ' '
  end

  # # expand one of the substitutions
  # def self.expand_sub sub
  #   case sub
  #   when Hash
  #     sub.map {|key, values|
  #       # keys need to be strings
  #       key = key.to_s unless key.is_a? String

  #       # for simplicity's sake, treat all values like an array
  #       values = [values] unless values.is_a? Array

  #       # if the key doesn't start with a `-` we want to add them
  #       unless key.start_with? '-'
  #         # if the key has length 1, we treat it like `-x <value>` style
  #         key = if key.length == 1
  #           '-' + key

  #         # longer keys are treated like `--blah=<value>` style
  #         else
  #           '--' + key + '='

  #       # now, if it ends with an '=' then put the value right next to it
  #       # like `--key=value`
  #       if key.end_with? '='
  #         values.map {|value| Shellwords.shellescape(key + value.to_s) }

  #       # 
  #       else

  #     }
  #   when Array
  # end

  # # substitute values into a command, escaping them for the shell and
  # # offering convenient expansions for some structures.
  # # 
  # # `cmd` is a string that can be substituted via ruby's `%` operator, like
  # # 
  # #     "git diff %s"
  # # 
  # # for positional substitution, or 
  # # 
  # #     "git diff %{path}"
  # # 
  # # for keyword substitution.
  # # 
  # # `subs` is either:
  # # 
  # # -   an Array when `cmd` has positional placeholders
  # # -   a Hash when `cmd` has keyword placeholders.
  # # 
  # # the elements of the `subs` array or values of the `subs` hash are:
  # # 
  # # -   strings that are substituted into `cmd` after being escaped:
  # #     
  # #         sub "git diff %{path}", path: "some path/to somewhere"
  # #         # => 'git diff some\ path/to\ somewhere'
  # # 
  # # -   hashes that are expanded into options:
  # #     
  # #         sub "psql %{opts} %{database} < %{filepath}",
  # #           database: "blah",
  # #           filepath: "/where ever/it/is.psql",
  # #           opts: {
  # #             username: "bingo bob",
  # #             host: "localhost",
  # #             port: 12345,
  # #           }
  # #         # => 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  # # 
  # def self.sub cmd, subs
  #   quoted = case subs
  #   when Hash
  #     Hash[
  #       subs.map do |key, sub|
  #         sub = File.join(*sub) if sub.is_a? Array
  #         # shellwords in 1.9.3 can't handle symbols
  #         sub = sub.to_s if sub.is_a? Symbol
  #         [key, Shellwords.escape(sub)]
  #       end
  #     ]
  #   when Array
  #     subs.map do |sub|
  #       sub = File.join(*sub) if sub.is_a? Array
  #       # shellwords in 1.9.3 can't handle symbols
  #       sub = sub.to_s if sub.is_a? Symbol
  #       Shellwords.escape sub
  #     end
  #   else
  #     raise "should be Hash or Array: #{ subs.inspect }"
  #   end
  #   command % quoted
  # end # ::sub
end # Cmds
