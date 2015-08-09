require 'erubis'

class Cmds
  # extension of Erubis' EscapedEruby (which auto-escapes `<%= %>` and
  # leaves `<%== %>` raw) that calls `Cmds.expand_sub` on the value
  class ShellEruby < Erubis::EscapedEruby
    def escaped_expr code
      "::Cmds.expand_sub(#{code.strip})"
    end
  end
end # class Cmds