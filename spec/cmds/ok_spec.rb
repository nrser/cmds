require 'spec_helper'

describe "Cmds::ok?" do
  it "works through instance method" do
    expect( Cmds.new("true").ok? ).to be true
    expect( Cmds.new("false").ok? ).to be false
  end

  it "works through class method" do
    expect( Cmds.ok? "true").to be true
    expect( Cmds.ok? "false").to be false
  end

  it "workds through global method" do
    expect( Cmds? "true" ).to be true
    expect( Cmds? "false" ).to be false
  end
end # Cmds::ok?