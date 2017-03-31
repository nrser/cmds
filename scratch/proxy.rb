require 'cmds'

Cmds.enable_debug do
  Cmds::Cmd.new("./test/questions.rb").proxy
end