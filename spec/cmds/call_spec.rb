require 'json'

require 'spec_helper'

describe "Cmds::call" do
  context "reused command" do
    let(:args_cmd) { Cmds.new "./test/echo_cmd.rb %s" }
    let(:kwds_cmd) { Cmds.new "./test/echo_cmd.rb %{s}" }

    it "is reusable" do
      {
        args_cmd => ["hey there"],
        kwds_cmd => {s: "hey there"},
      }.each do |cmd, arg|
        result = cmd.call arg

        expect( result.ok? ).to be true

        expect( JSON.load(result.out)['ARGV'][0] ).to eq "hey there"
      end # each cmd => arg
    end # is reusable
  end # reused command
end # Cmds::run