# encoding: UTF-8
# frozen_string_literal: true

require 'active_support/core_ext/object/deep_dup'

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
    # Alphabetical...
    
    # positional arguments for a command
    args: [],
    
    # what to join array option values with when using `array_mode = :join`
    array_join_string: ',',
    
    # what to do with array option values
    array_mode: :join,
    
    # Don't asset (raise error if exit code is not 0)
    assert: false,
    
    # Don't change directories
    chdir: nil,
    
    # Commands often use dash-separated option names, but it's a lot more
    # convenient in Ruby to use underscored when using {Symbol}. This option
    # will convert the underscores to dashes.
    dash_opt_names: false,
    
    # No additional environment
    env: {},
    
    # Stick ENV var defs inline at beginning of command
    env_mode: :inline,
    
    # What to do with `false` *option* values (not `false` values as regular
    # values or inside collections)
    # 
    # Just leave them out all-together
    false_mode: :omit,
    
    # Flatten nested array values to a single array.
    # 
    # Many CLI commands accept arrays in some form or another, but I'm hard
    # pressed to think of one that accepts nested arrays. Flattening can make
    # it simpler to generate values.
    # 
    flatten_array_values: true,
    
    # how to format a command string for execution
    format: :squish,
    
    hash_mode: :join,
    
    # Join hash keys and values with `:`
    hash_join_string: ':',
    
    # No input
    input: nil,
    
    # keyword arguments for a command
    kwds: {},

    # What to use to separate "long" opt names (more than one character) from
    # their values. I've commonly seen '=' (`--name=VALUE`)
    # and ' ' (`--name VALUE`).
    long_opt_separator: '=',
    
    # What to use to separate "short" opt names (single character) from their
    # values. I've commonly seen ' ' (`-x VALUE`) and '' (`-xVALUE`).
    short_opt_separator: ' ',
    
  }.map { |k, v| [k, v.freeze] }.to_h.freeze
  
  
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
      DEFAULTS.deep_dup
    else
      keys.
        map {|key|
          [key, DEFAULTS.fetch(key)]
        }.
        to_h
    end.
      merge!( extras ).
      merge!( opts )
  end
  
  
  # proxy through to class method {Cmds.defaults}.
  # 
  def defaults opts, keys = '*', extras = {}
    self.class.defaults opts, keys, extras
  end
  
end
