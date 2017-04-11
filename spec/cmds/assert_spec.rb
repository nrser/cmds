require 'spec_helper'

describe "Cmds::assert" do
  it "should raise an error when the command fails" do
    expect{ Cmds.assert "exit 1" }.to raise_error Errno::EPERM
  end

  it "should do the same for Cmds!" do
    expect{ Cmds! "exit 1" }.to raise_error Errno::EPERM
  end

  it "should be chainable when the command is ok" do
    expect( Cmds!("echo hey").out ).to eq "hey\n"
    expect( Cmds.new("echo hey").capture.assert.out ).to eq "hey\n"
  end
end # Cmds::run