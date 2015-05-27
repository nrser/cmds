require 'spec_helper'

describe "Cmds.sub" do
  it "should work with a hash" do
    expect(
      Cmds.sub "psql %{opts} %{database} < %{filepath}",
        database: "blah",
        filepath: "/where ever/it/is.psql",
        opts: {
          username: "bingo bob",
          host: "localhost",
          port: 12345,
        }
    ).to eq 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  end

  it "should work with an array" do
    expect(
      Cmds.sub "psql %s %s < %s", [
        {
          username: "bingo bob",
          host: "localhost",
          port: 12345,
        },
        "blah",
        "/where ever/it/is.psql",
      ]
    ).to eq 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  end

  it "should raise TypeError if subs in not an array or a hash" do
    expect{Cmds.sub "a %{b} %{c}", "dee!"}.to raise_error TypeError
  end
end # ::sub