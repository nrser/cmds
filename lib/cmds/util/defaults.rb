class Cmds
  # hash of common default values used in method options.
  # 
  # don't use them directly -- use {Cmds.defaults}.
  # 
  # the values themselves are frozen so we don't have to worry about cloning
  # them before providing them for use.
  # 
  # the constant Hash itself is **not** frozen -- you can mutate this to
  # change the default options for **ALL** Cmds method calls...
  # just be aware of what you're doing. not recommended
  # outside of quick hacks and small scripts since other pieces and parts
  # you don't even know about may depend on said behavior.
  # 
  DEFAULTS = {
    # positional arguments for a command
    args: [],
    
    # keyword arguments for a command
    kwds: {},
    
    # how to format a command string for execution
    format: :squish,
    
    # what to do with array option values
    array_mode: :join,
    
    # what to join array option values with when using `array_mode = :join`
    array_join_string: ',',
    
    # what to do with false array values
    false_mode: :omit,
  }.map {|k, v| [k, v.freeze]}.to_h
  
  # merge an method call options hash with common defaults for the module.
  # 
  # this makes it easy to use the same defaults in many different methods
  # without repeating the declarations everywhere.
  # 
  # @param [Hash] opts
  #   hash of overrides provided by method caller.
  # 
  # @param [Array<Symbol>, '*'] keys
  #   keys for the defaults you want to use.
  # 
  # @param [Hash<Symbol, Object>] extras
  #   extra keys and values to add to the returned defaults.
  # 
  # @return [Hash<Symbol, Object>]
  #   defaults to use in the method call.
  #   
  def self.defaults opts, keys = '*', extras = {}
    if keys == '*'
      DEFAULTS
    else      
      keys.
        map {|key|
          [key, DEFAULTS.fetch(key)]
        }.
        to_h
    end.
      merge!(extras).
      merge!(opts)
  end
  
  # proxy through to class method {Cmds.defaults}.
  # 
  def defaults opts, keys = '*', extras = {}
    self.class.defaults opts, keys, extras
  end
end
