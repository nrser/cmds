require 'spec_helper'

describe "Cmds::ok?" do
  it "works" do
    expect( Cmds.ok? "true").to be true
    expect( Cmds.ok? "false").to be false
  end
end # Cmds::ok?