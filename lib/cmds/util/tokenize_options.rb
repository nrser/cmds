require_relative 'tokenize_option'

module Cmds
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
  def self.tokenize_options hash, opts = {}
    opts = defaults opts, [:array_mode, :array_join_string, :false_mode]
    
    hash.map {|key, value|
      # keys need to be strings
      key = key.to_s unless key.is_a? String

      [key, value]

    }.sort {|(key_a, value_a), (key_b, value_b)|
      # sort by the (now string) keys
      key_a <=> key_b

    }.map {|key, value|
      tokenize_option key, value
      
    }.flatten.join ' '
  end # .tokenize_options
end