require 'json'

require 'spec_helper'

describe "Cmds::run" do
  context "when echo_cmd.rb is called with 'hello world!'" do

    let(:result) {
      Cmds "./test/echo_cmd.rb %s", ["hello world!"]
    }

    it "should be ok" do
      expect( result.ok? ).to be true
    end

    it "should have empty err" do
      expect( result.err ).to eq ""
    end

    it "should have 'hello world!' as ARGV[0]" do
      expect( JSON.load(result.out)['ARGV'][0] ).to eq "hello world!"
    end
  end
end