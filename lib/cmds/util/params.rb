module Cmds
  class Params
    # Cmds instance execution methods take a splat and block 
    def self.normalize *params, &input
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
    end # .normalize
  end # Params
end # Cmds