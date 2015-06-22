require 'json'

require 'spec_helper'

describe "Cmds::run" do
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
end # Cmds::run