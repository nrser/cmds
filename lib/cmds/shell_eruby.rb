require 'erubis'

module Cmds
  # extension of Erubis' EscapedEruby (which auto-escapes `<%= %>` and
  # leaves `<%== %>` raw) that calls `Cmds.expand_sub` on the value
  class ShellEruby < Erubis::EscapedEruby
    def escaped_expr code
      "::Cmds.tokenize(#{code.strip})"
    end
  end
end # module Cmds