$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'cmds'

shared_examples "ok" do
  it "should be ok" do
    expect( result.ok? ).to be true
  end

  it "should have empty err" do
    expect( result.err ).to eq ""
  end
end # ok
