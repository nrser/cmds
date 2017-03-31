require 'spec_helper'

describe "Cmds.error?" do
  it "works through instance method" do
    expect( Cmds::Cmd.new("true").error? ).to be false
    expect( Cmds::Cmd.new("false").error? ).to be true
  end

  it "works through class method" do
    expect( Cmds.error? "true" ).to be false
    expect( Cmds.error? "false" ).to be true
  end
end # Cmds.error?