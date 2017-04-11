require 'spec_helper'

describe "Cmds.chomp" do
  it "gets echo output" do
    expect( Cmds.chomp "echo %s", "hey there!" ).to eq "hey there!"
  end

  it "reads input" do
    expect(
      Cmds.chomp("ruby -e %{script}", script: "puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!"
  end
end # Cmds.chomp

describe "Cmds.chomp!" do
  it "gets echo output" do
    expect( Cmds.chomp! "echo %s", "hey there!" ).to eq "hey there!"
  end

  it "reads input" do
    expect(
      Cmds.chomp!("ruby -e %{script}", script: "puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!"
  end

  it "errors when the command fails" do
    expect { Cmds.chomp! "false" }.to raise_error SystemCallError
  end
end # Cmds.chomp!

describe "Cmds#chomp" do
  it "gets echo output" do
    expect( Cmds.new("echo %s").chomp "hey there!" ).to eq "hey there!"
  end

  it "reads input" do
    expect(
      Cmds.new("ruby -e %{script}").chomp(script: "puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!"
  end
end # Cmds#chomp

describe "Cmds#chomp!" do
  it "gets echo output" do
    expect( Cmds.new("echo %s").chomp! "hey there!" ).to eq "hey there!"
  end

  it "reads input" do
    expect(
      Cmds.new("ruby -e %{script}").chomp!(script: "puts STDIN.read") {
        "hey there!"
      }
    ).to eq "hey there!"
  end

  it "errors when the command fails" do
    expect { Cmds.new("false").chomp! }.to raise_error SystemCallError
  end
end # Cmds#chomp!
