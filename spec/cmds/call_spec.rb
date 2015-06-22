require 'json'

require 'spec_helper'

describe "Cmds::call" do
  it "is reusable" do
    args_cmd = Cmds.new "./test/echo_cmd.rb <%= arg %>"
    kwds_cmd = Cmds.new "./test/echo_cmd.rb <%= s %>"

    ["arg one", "arg two", "arg three"].each do |arg|
      [args_cmd.call([arg]), kwds_cmd.call(s: arg)].each do |result|
        expect( result.ok? ).to be true
        expect( JSON.load(result.out)['ARGV'][0] ).to eq arg
      end
    end
  end # is reusable
end # Cmds::run