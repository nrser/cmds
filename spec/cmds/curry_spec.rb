require 'spec_helper'

describe "Cmds::curry" do
  it "currys" do
    base = Cmds::Cmd.new "#{ ECHO_CMD } <%= x %> <%= y %>"

    x1 = base.curry x: 1
    x2 = base.curry x: 2

    expect( echo_cmd_argv x1.call y: 'why' ).to eq ['1', 'why']
    expect( echo_cmd_argv x2.call y: 'who' ).to eq ['2', 'who']
    expect( echo_cmd_argv base.call x: 3, y: 4 ).to eq ['3', '4']
  end # it currys
end # Cmds::run