class Cmds
  class Params
    # Cmds instance execution methods take a splat and block
    def self.normalize *_params, &input
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
          raise TypeError,
                "first *subs arg must be Array or Hash, not #{subs[0].inspect}"
        end

      when 2
        # first arg needs to be an array, second a hash
        unless subs[0].is_a? Array
          raise TypeError,
                "first *subs arg needs to be an array, not #{subs[0].inspect}"
        end

        unless subs[1].is_a? Hash
          raise TypeError,
                "second *subs arg needs to be a Hash, not #{subs[1].inspect}"
        end

        args, kwds = subs
      else
        raise ArgumentError,
              "must provide one or two *subs arguments, received #{1 + subs.length}"
      end

      {
        args: args,
        kwds: kwds,
        input: input
      }
    end # .normalize
  end # Params
end # Cmds
