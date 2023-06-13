describe 'Cmds.quote_dance' do
  it do
    expect(Cmds.quote_dance("you're", :single)).to eq %('you'"'"'re')
    expect(Cmds.quote_dance('such a "goober" dude', :double)).to eq %("such a "'"'"goober"'"'" dude")
    expect(Cmds.quote_dance(%(hey "ho" let's go), :double)).to eq %("hey "'"'"ho"'"'" let's go")

    expect { Cmds.quote_dance 'blah', :not_there }.to raise_error KeyError
  end
end # spec file
