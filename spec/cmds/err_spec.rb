require 'spec_helper'

describe "Cmds.err" do
  it "gets echo error output" do
    expect( Cmds.err "echo %s 1>&2", "hey there!" ).to eq "hey there!\n"
  end

  it "reads input" do
    expect(
      Cmds.err("ruby -e %{script}", script: "$stderr.puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!\n"
  end
end # Cmds.err

describe "Cmds#err" do
  it "gets echo error output" do
    expect( 
      Cmds.new("echo %s 1>&2").err "hey there!"
    ).to eq "hey there!\n"
  end

  it "reads input" do
    expect(
      Cmds.new("ruby -e %{script}").
        err(script: "$stderr.puts STDIN.read") {
          "hey there!"
        }
    ).to eq "hey there!\n"
  end
end # Cmds.err
