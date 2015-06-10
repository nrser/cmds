require 'json'

require 'spec_helper'

describe "Cmds::run" do
  shared_examples "ok" do
    it "should be ok" do
      expect( result.ok? ).to be true
    end

    it "should have empty err" do
      expect( result.err ).to eq ""
    end
  end # ok

  context "echo_cmd.rb 'hello world!'" do

    shared_examples "executes correctly" do
      it_behaves_like "ok"

      it "should have 'hello world!' as ARGV[0]" do
        expect( JSON.load(result.out)['ARGV'][0] ).to eq "hello world!"
      end
    end # executes correctly

    context "positional args" do
      let(:result) {
        Cmds "./test/echo_cmd.rb %s", ["hello world!"]
      }

      it_behaves_like "executes correctly"
    end

    context "keyword args" do
      let(:result) {
        Cmds "./test/echo_cmd.rb %{s}", s: "hello world!"
      }

      it_behaves_like "executes correctly"
    end

  end # context echo_cmd.rb 'hello world!'

  it "should error when second (subs) arg is not a hash or array" do
    expect {
      Cmds "./test/echo_cmd.rb %s", "hello world!"
    }.to raise_error TypeError
  end
end # Cmds::run