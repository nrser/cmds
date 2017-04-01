require 'spec_helper'

describe "Cmds ENV vars" do
  it "sets basic string ENV var" do
    cmd = Cmds::Cmd.new 'echo "${BLAH}"', env: {BLAH: "x:y:z"}
    expect(cmd.chomp!).to eq "x:y:z"
  end
end