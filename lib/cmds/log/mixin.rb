# encoding: UTF-8
# frozen_string_literal: true


# Definitions
# =======================================================================

# Adaptation of {SemanticLogger::Loggable} mixin to use {Cmds::Log::Logger}
# instances from {Cmds::Log.[]}.
# 
# Like {SemanticLogger::Loggable} adds class and instance `logger` and
# `logger=` methods that create loggers on demand and store them in the
# `@semantic_logger` instance variables.
# 
module Cmds::Log::Mixin
  
  # Methods to mix into the including class.
  # 
  module ClassMethods
    
    protected
    # ========================================================================
      
      def create_logger
        Cmds::Log[self]
      end
      
    public # end protected ***************************************************
    
    # Returns [SemanticLogger::Logger] class level logger
    def logger
      @semantic_logger ||= create_logger
    end

    # Replace instance class level logger
    def logger= logger
      @semantic_logger = logger
    end
    
  end
  
  
  # Class Methods
  # ========================================================================
  
  def self.included base
    base.extend ClassMethods
    
    # Adds `.logger_measure_method`
    base.extend SemanticLogger::Loggable::ClassMethods
  end
  
  
  # Instance Methods
  # ========================================================================
  
  # Gets the {Cmds::Log::Logger} for use in the instance. This will be the
  # class logger from {ClassMethods#logger} unless the instance has a
  # `#create_logger` method.
  # 
  # The `#create_logger` method is expected to return a {Cmds::Log::Logger}
  # instance, which will be saved in the `@semantic_logger` instance variable
  # for future use.
  # 
  # That method does not need to return a different logger for every instance
  # - if you just want to have a different logger for *all* instance with a
  # different level or formatter or whatever, you can save it somewhere else
  # and always return that same instance.
  # 
  # If you are dealing with frozen instances make sure to call `#logger` before
  # you freeze (likely in the constructor). If you don't want to save the
  # logger at all, just override this method itself.
  # 
  # This is a departure from {SemanticLogger::Loggable} that started because
  # if the instance is frozen then attempting to set `@semantic_logger` will
  # raise an error.
  # 
  # I also started ending up with classes that wanted to individually
  # configure their loggers, so it seemed like we could take out two birds
  # with this stone.
  # 
  # @return [SemanticLogger::Logger]
  #   Instance level logger, if {ClassMethods.instance_logger?},
  #   otherwise the class level logger from {ClassMethods#logger}.
  # 
  def logger
    return @semantic_logger if @semantic_logger
    
    if respond_to?( :create_logger, true )
      @semantic_logger = begin
        create_logger
      rescue Exception => error
        self.class.logger.warn \
          "Error creating instance logger",
          { instance: self.inspect },
          error
        
        self.class.logger
      end
    else
      self.class.logger
    end
  end
  
  
  # Replace instance level logger
  def logger= logger
    @semantic_logger = logger
  end
  
end # module Cmds::Log::Mixin
