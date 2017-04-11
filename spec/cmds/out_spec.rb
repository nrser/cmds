require 'spec_helper'

describe "Cmds.out" do
  it "gets echo output" do
    expect( Cmds.out "echo %s", "hey there!" ).to eq "hey there!\n"
  end

  it "reads input" do
    expect(
      Cmds.out("ruby -e %{script}", script: "puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!\n"
  end
end # Cmds.out

describe "Cmds.out!" do
  it "gets echo output" do
    expect( Cmds.out! "echo %s", "hey there!" ).to eq "hey there!\n"
  end

  it "reads input" do
    expect(
      Cmds.out!("ruby -e %{script}", script: "puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!\n"
  end

  it "errors when the command fails" do
    expect { Cmds.out! "false" }.to raise_error SystemCallError
  end
end # Cmds.out!

describe "Cmds#out" do
  it "gets echo output" do
    expect( Cmds.new("echo %s").out "hey there!" ).to eq "hey there!\n"
  end

  it "reads input" do
    expect(
      Cmds.new("ruby -e %{script}").out(script: "puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!\n"
  end
end # Cmds#out

describe "Cmds#out!" do
  it "gets echo output" do
    expect( Cmds.new("echo %s").out! "hey there!" ).to eq "hey there!\n"
  end

  it "reads input" do
    expect(
      Cmds.new("ruby -e %{script}").out!(script: "puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!\n"
  end

  it "errors when the command fails" do
    expect { Cmds.new("false").out! }.to raise_error SystemCallError
  end
end # Cmds#out!
