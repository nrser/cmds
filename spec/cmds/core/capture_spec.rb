require 'spec_helper'

describe "Cmds::capture" do
  it "is reusable" do
    args_cmd = Cmds.new "./test/echo_cmd.rb <%= arg %>"
    kwds_cmd = Cmds.new "./test/echo_cmd.rb <%= s %>"

    args = ["arg one", "arg two", "arg three"]

    args.each do |arg|
      results = [
        args_cmd.capture([arg]),
        kwds_cmd.capture(s: arg)
      ]

      results.each do |result|
        expect( echo_cmd_argv result ).to eq [arg]
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
      cmd = Cmds.new(ECHO_CMD, input: input)
      expect( echo_cmd_stdin cmd.capture ).to eq input
    end

    it "accepts input via block" do
      cmd = Cmds.new ECHO_CMD
      expect( echo_cmd_stdin cmd.call { input } ).to eq input
    end

    it "accepts input from a stream" do
      File.open "./test/lines.txt" do |f|
        input = f.read
        f.rewind

        cmd = Cmds.new ECHO_CMD
        expect( echo_cmd_stdin cmd.capture { f } ).to eq input
      end
    end
  end # context input
end # Cmds::capture