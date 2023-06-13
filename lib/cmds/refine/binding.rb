require 'cmds/util/text'

class Cmds
  module Refine
    refine Binding do
      # Calls {NRSER.template} with `self` prepended to `*args`
      #
      # @param (see NRSER.erb)
      # @return (see NRSER.erb)
      #
      def erb(source)
        require 'erb'

        Text.filter_repeated_blank_lines(
          Text.with_indent_tagged(Text.dedent(source)) do |tagged_str|
            ERB.new(tagged_str).result(self)
          end,
          remove_leading: true
        )
      end

      alias_method :template, :erb

      # Get a {Hash} of all local variable names (as {Symbol}) to values.
      #
      # @return [Hash<Symbol, Object>]
      #
      def locals
        self.local_variables.assoc_to { |symbol| local_variable_get symbol }
      end

      # Get a {Array} of all local variable values.
      #
      # @return [Array<Object>]
      #
      def local_values
        self.local_variables.map { |symbol| local_variable_get symbol }
      end
    end
  end # module Refine
end # class Cmds
