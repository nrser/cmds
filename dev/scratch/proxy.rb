require 'cmds'

Cmds.enable_debug do
  Cmds.new("./test/questions.rb").proxy
end