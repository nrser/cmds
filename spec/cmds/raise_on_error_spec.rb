require 'spec_helper'

describe "Cmds::assert" do
  it "should raise an error when the command fails" do
    expect{ Cmds.assert "exit 1" }.to raise_error Errno::EPERM
  end

  it "should do the same for Cmds!" do
    expect{ Cmds! "exit 1" }.to raise_error Errno::EPERM
  end
end # Cmds::run