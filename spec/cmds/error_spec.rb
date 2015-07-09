require 'spec_helper'

describe "Cmds::error?" do
  it "works" do
    expect( Cmds.error? "true").to be false
    expect( Cmds.error? "false").to be true
  end
end # Cmds::ok?