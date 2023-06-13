# encoding: UTF-8
# frozen_string_literal: true

# Requirements
# =======================================================================

# Stdlib
# -----------------------------------------------------------------------

# Deps
# -----------------------------------------------------------------------

# Project / Package
# -----------------------------------------------------------------------


# Refinements
# =======================================================================


# Declarations
# =======================================================================

module Cmds::Log; end
module Cmds::Log::Formatters; end


# Definitions
# =======================================================================

# A mix-in to include in {SemanticLogger::Formatter::Default} and subclasses
# to improve configurability.
# 
module Cmds::Log::Formatters::Mixin
  
  # Inner Classes
  # ==========================================================================
  # 
  # Small helper classes only created via the mix-in.
  # 
  
  # Abstract base class for {HeaderTokens} and {BodyTokens}, instances of which are used
  # by formatters that include {Cmds::Log::Formatters::Mixin} to
  # configure what pieces of information make up the header and body sections
  # of log messages that it formats.
  # 
  # Entries are {SemanticLogger::Formatter::Default} method names, which I've
  # called "tokens", and the order of the "tokens" dictates the order the
  # results of those method calls will be joined to form the formatted
  # message section.
  # 
  # Adding, removing and reordering tokens is used to control what elements
  # appear and where in the formatted result.
  # 
  # Token arrays are mutable and meant to changed in place via {Array#delete}
  # and friends.
  # 
  class Tokens < ::Array
    # Create a new token array.
    # 
    # @param [Array<#to_sym>] tokens
    #   The token symbols to initialize the array with. Must be covetable
    #   to symbols (really, just pass symbols in the first place).
    # 
    def initialize tokens = self.class::ALL
      super tokens.map( &:to_sym )
    end
    
    
    # Reset the array to be all the available tokens for the section in
    # their original order.
    # 
    # **Mutates the array in place.**
    # 
    # @return [Tokens]
    #   `self`.
    # 
    def reset!
      clear
      self.class::ALL.each { |token| self << token }
      self
    end
  end # class Tokens
  
  
  # {Tokens} subclass for log message headers.
  # 
  # @see #header
  # @see #header=
  # 
  class HeaderTokens < Tokens
    # All header tokens in a default order.
    # 
    # @return [Array<Symbol>]
    # 
    ALL = [
      :time,
      :level,
      :process_info,
      :tags,
      :named_tags,
      :duration,
      :name,
    ].freeze
  end
  
  
  # {Tokens} subclass for log message bodies.
  # 
  # @see #body
  # @see #body=
  # 
  class BodyTokens < Tokens
    # All body tokens in a default order.
    # 
    # @return [Array<Symbol>]
    # 
    ALL = [
      :message,
      :payload,
      :exception,
    ]
  end
  
  
  # Instance Methods
  # ========================================================================
  
  # Get or set the header "tokens" - {SemanticLogger::Formatters::Default}
  # method names in the order their responses should be joined to form the
  # header section of formatted log messages (time, level, name, etc.).
  # 
  # @example Getting the {HeaderTokens}
  #   # You won't see much unless logging is setup
  #   Cmds::Log.setup! dest: $stdout, level: :info
  #   
  #   # Full object path to HeaderTokens - there's also a {Cmds::Log.header}
  #   # shortcut
  #   Cmds::Log.appender.formatter.header
  #   # => [:time, :level, :process_info, :tags, :named_tags, :duration, :name]
  #   
  #   Cmds.logger.info "Hey yo!"
  #   # > 2018-04-12 23:43:24.982040 INFO [19301:main] Cmds
  #   # > -- Hey yo!
  #   # >
  #   # => true
  # 
  # @example Setting the {HeaderTokens}
  #   # You won't see much unless logging is setup
  #   Cmds::Log.setup! dest: $stdout, level: :info
  #   
  #   # Set a very simple header
  #   Cmds::Log.header :level, :name
  #   # => [:level, :name]
  #   
  #   # And notice the reduced log header
  #   Cmds.logger.info "Hey yo!"
  #   # > INFO Cmds
  #   # > -- Hey yo!
  #   # >
  #   # => true
  # 
  # @param [Array<Symbol>] tokens
  #   Optional list of token symbols to set as the header format.
  #   
  #   When empty, the method works as a getter, returning the current header
  #   format tokens.
  # 
  # @return [HeaderTokens]
  #   The current header tokens.
  # 
  def header *tokens
    if tokens.empty?
      @header ||= HeaderTokens.new
    else
      @header = HeaderTokens.new tokens
    end
  end
  
  
  # Set the header section format tokens.
  # 
  # See {#header} for details and examples of how the header works.
  # 
  # @see #header
  # 
  # @param [Array<Symbol>] tokens
  #   Token symbols to set as the header format.
  # 
  # @return [HeaderTokens]
  #   The new header format.
  # 
  def header= tokens
    @header = HeaderTokens.new tokens
  end
  
  
  # Get or set the body section tokens.
  # 
  # Just like {#header}, which has details and examples, but for the "body"
  # section of log messages (message, payload, exception).
  # 
  # @see #header
  # 
  # @param [Array<Symbol>] tokens
  #   When not empty, sets the body to those tokens in that order.
  #   
  #   When empty, the current body is returned.
  # 
  # @return [BodyTokens]
  #   The new and/or current body.
  # 
  def body *tokens
    if tokens.empty?
      @body ||= BodyTokens.new
    else
      @body = BodyTokens.new tokens
    end
  end
  
  
  # Set the body section format tokens.
  # 
  # See {#header} for details and examples of how the header works.
  # 
  # @see #header
  # 
  # @param [Array<Symbol>] tokens
  #   Token symbols to set as the body format.
  # 
  # @return [HeaderTokens]
  #   The new body format.
  # 
  def body= tokens
    @body = BodyTokens.new tokens
  end
  
  
  protected
  # ========================================================================
    
    # Use {#header} to render the header string for the current log.
    # 
    # @return [String]
    # 
    def render_header
      header.map( &method( :send ) ).compact.join ' '
    end # #header
    
    
    # Use {#body} to render the header string for the current log.
    # 
    # @return [String]
    # 
    def render_body
      body.map( &method( :send ) ).compact.join ' '
    end
    
    
    # Render the current log message using {#render_header} and {#render_body}.
    # 
    # @return [String]
    # 
    def render_log
      render_header + "\n" + render_body + "\n"
    end
    
  public # end protected ***************************************************
  
end # module Cmds::Log::Formatter::Mixin
