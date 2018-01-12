describe_spec_file(
  spec_path: __FILE__,
  module: Cmds,
  method: :quote_dance,
) do
  
  it_behaves_like "function",
    mapping: {
      ["you're", :single] => %{'you'"'"'re'},
      ['such a "goober" dude', :double] => %{"such a "'"'"goober"'"'" dude"},
      [%{hey "ho" let's go}, :double] => %{"hey "'"'"ho"'"'" let's go"}
    },
    
    raising: {
      ["blah", :not_there] => KeyError,
    }
  
end # spec file
