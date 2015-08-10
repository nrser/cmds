require 'json'

require 'spec_helper'

describe "Cmds::capture" do
  it "is reusable" do
    args_cmd = Cmds.new "./test/echo_cmd.rb <%= arg %>"
    kwds_cmd = Cmds.new "./test/echo_cmd.rb <%= s %>"

    ["arg one", "arg two", "arg three"].each do |arg|
      [args_cmd.capture([arg]), kwds_cmd.capture(s: arg)].each do |result|
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
      cmd = Cmds.new "wc -l", input: input
      result = cmd.capture
      expect( result.out ).to match /^\s+4$/
    end

    it "accepts input via block" do
      cmd = Cmds.new "wc -l"
      expect(cmd).to be_instance_of Cmds
      expect(cmd).to respond_to :capture

      result = cmd.call { input }
      expect(result).to be_instance_of Cmds::Result
      expect(result.out).to match /^\s+4$/
    end

    it "accepts input from a stream" do
      File.open "./test/lines.txt" do |f|
        input = f.read
        f.rewind

        result = echo_cmd.capture { f }

        expect(JSON.load(result.out)['stdin']).to eq input
      end
    end
  end # context input
end # Cmds::call