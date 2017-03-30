require 'spec_helper'

describe Cmds do
  it 'has a version number' do
    expect(Cmds::VERSION).not_to be nil
  end
  
  it "has dees syntax" do
    expect(Cmds.chomp! "echo 'here'").to eq 'here'
    
    expect(
      Cmds.new("head %{opts} %s").
        curry("/dev/random", opts: {c: 64}).
        to_s
    ).to eq "head -c 64 /dev/random"
    
    expect(Cmds.chomp! "echo %s", 'here').to eq 'here'
  end
end
