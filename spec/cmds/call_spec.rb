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

  context "input" do
    let(:input) {
      <<-BLOCK
        one
        two
        three
        four!
      BLOCK
    }

    it "accepts input via options" do
      expect( Cmds.new("wc -l", input: input).call.out ).to match /^\s+4$/
    end

    it "accepts input via block" do
      cmds = Cmds.new("wc -l")
      expect(cmds).to be_instance_of Cmds
      expect(cmds).to respond_to :call

      result = cmds.call { input }
      expect(result).to be_instance_of Cmds::Result
      expect(result.out).to match /^\s+4$/
    end
  end # context input
end # Cmds::call