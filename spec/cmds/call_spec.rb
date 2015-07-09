require 'json'

require 'spec_helper'

describe "Cmds::call" do
  it "is reusable" do
    args_cmd = Cmds.new "./test/echo_cmd.rb <%= arg %>"
    kwds_cmd = Cmds.new "./test/echo_cmd.rb <%= s %>"

    ["arg one", "arg two", "arg three"].each do |arg|
      [args_cmd.call([arg]), kwds_cmd.call(s: arg)].each do |result|
        expect_argv( result ).to eq [arg]
      end
    end
  end # is reusable

  it "accepts input" do
    input = <<-BLOCK
    one
    two
    three
    four!
    BLOCK

    expect( Cmds.new("wc -l", input: input).call.out ).to match /^\s+4$/
  end
end # Cmds::call