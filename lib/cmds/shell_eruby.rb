require 'erubis'

class Cmds
  # extension of Erubis' EscapedEruby (which auto-escapes `<%= %>` and
  # leaves `<%== %>` raw) that calls `Cmds.expand_sub` on the value
  class ShellEruby < Erubis::EscapedEruby
    def escaped_expr code
      "::Cmds.tokenize(#{code.strip}, **@tokenize_options_opts)"
    end
  end
end # class Cmds