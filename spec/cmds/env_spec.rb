require 'spec_helper'

describe "Cmds ENV vars" do
  it "sets basic (path-like) string ENV var" do
    cmd = Cmds::Cmd.new 'echo "${BLAH}"', env: {BLAH: "x:y:z"}
    expect(cmd.chomp!).to eq "x:y:z"
  end
  
  it "sets a string with spaces in it correctly" do
    cmd = Cmds::Cmd.new 'echo "${BLAH}"', env: {BLAH: "hey there"}
    expect(cmd.chomp!).to eq "hey there"
  end
end