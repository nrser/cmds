require 'spec_helper'

describe "Cmds::capture" do
  it "captures stdout" do
    expect(
      Cmds.new(%{ruby -e '$stdout.puts "hey"'}).capture.out
    ).to eq "hey\n"
  end

  it "captures stderr" do
    expect(
      Cmds.new(%{ruby -e '$stderr.puts "ho"'}).capture.err
    ).to eq "ho\n"
  end

  context "echo_cmd.rb 'hello world!'" do

    shared_examples "executes correctly" do
      it_behaves_like "ok"

      it "should have 'hello world!' as ARGV[0]" do
        expect( JSON.load(result.out)['ARGV'][0] ).to eq "hello world!"
      end
    end # executes correctly

    context "positional args" do
      let(:result) {
        Cmds "./test/echo_cmd.rb <%= arg %>", ["hello world!"]
      }

      it_behaves_like "executes correctly"
    end

    context "keyword args" do
      let(:result) {
        Cmds "./test/echo_cmd.rb <%= s %>", s: "hello world!"
      }

      it_behaves_like "executes correctly"
    end

  end # context echo_cmd.rb 'hello world!'

  # context "feeding kwargs to args cmd" do
  #   let(:result) {
  #     Cmds "./test/echo_cmd.rb %s", s: "sup y'all"
  #   }

  #   it "" do
  #     expect( result.cmd ).to eq nil
  #   end
  # end

  it "should error when second (subs) arg is not a hash or array" do
    expect {
      Cmds "./test/echo_cmd.rb <%= arg %>", "hello world!"
    }.to raise_error TypeError
  end

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
      expect( echo_cmd_stdin cmd.capture { input } ).to eq input
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