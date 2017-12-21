require 'json'
require 'nrser/refinements'

require_relative "defaults"

class Cmds
  TOKENIZE_OPT_KEYS = [:array_mode, :array_join_string, :false_mode]
  
  # turn an option name and value into an array of shell-escaped string
  # token suitable for use in a command.
  # 
  # @param [String] name
  #   string name (one or more characters).
  # 
  # @param [*] value
  #   value of the option.
  # 
  # @param [Hash] **opts
  # @option [Symbol] :array_mode (:multiple)
  #   one of:
  #   
  #   1.  `:multiple` (default) provide one token for each value.
  #       
  #           expand_option 'blah', [1, 2, 3]
  #           => ['--blah=1', '--blah=2', '--blah=3']
  #   
  #   2.  `:join` -- join values in one token.
  #         
  #           expand_option 'blah', [1, 2, 3], array_mode: :join
  #           => ['--blah=1,2,3']
  # 
  # @option [String] :array_join_string (',')
  #   string to join array values with when `:array_mode` is `:join`.
  # 
  # @return [Array<String>]
  #   string tokens.
  # 
  def self.tokenize_option name, value, **opts
    opts = defaults opts, TOKENIZE_OPT_KEYS
    
    unless name.is_a?(String) && name.length > 0
      raise ArgumentError.new NRSER.squish <<-END
        `name` must be a String of length greater than zero,
        found #{ name.inspect }
      END
    end
    
    prefix, separator = if name.length == 1
      # -b <value> style
      ['-', ' ']
    else
      # --blah=<value> style
      ['--', '=']
    end
      
    case value
    when nil
      []
      
    when Array
      # the PITA one
      case opts[:array_mode]
      when :repeat
        # `-b 1 -b 2 -b 3` / `--blah=1 --blah=2 --blah=3` style
        value.flatten.map {|v|
          prefix + esc(name) + separator + esc(v)
        }
        
      when :join
        # `-b 1,2,3` / `--blah=1,2,3` style
        [ prefix + 
          esc(name) + 
          separator + 
          esc(value.join opts[:array_join_string]) ]
        
      when :json
        [prefix + esc(name) + separator + "'" + JSON.dump(value).gsub(%{'}, %{'"'"'}) + "'"]
        
      else
        # SOL
        raise ArgumentError.new NRSER.squish <<-END
          bad array_mode option: #{ opts[:array_mode] }, 
          should be :repeat, :join or :json
        END
        
      end
      
    when true
      # `-b` or `--blah`
      [prefix + esc(name)]
      
    when false
      case opts[:false_mode]
      when :omit
        # don't emit any token for a false boolean
        []
      when :no
        # `--no-blah` style
        # 
        # but there's not really a great way to handle short names...
        # we use `--no-b`
        # 
        ["--no-#{ esc(name) }"]
        
      else
        raise ArgumentError.new NRSER.squish <<-END
          bad :false_mode option: #{ opts[:false_mode] }, 
          should be :omit or :no
        END
      end
      
    else
      # we let .esc handle it
      [prefix + esc(name) + separator + esc(value)]
      
    end
  end
end