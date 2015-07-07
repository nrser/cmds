require 'spec_helper'

def expect_to_replace input, output
  [
    "#{ input }",
    "blah #{ input }",
    "#{ input } blah",
    "blah\n#{ input }\nblah",
  ].each do |str|
    expect( Cmds.replace_shortcuts input ).to eq output
  end
end

describe 'Cmds::replace_shortcuts' do
  it "should replace %s with <%= arg %>" do
    expect_to_replace "%s", "<%= arg %>"
  end

  it "should replace %%s with %s (escaping)" do
    expect_to_replace "%%s", "%s"
  end

it "should replace %%%s with %%s (escaping)" do
    expect_to_replace "%%%s", "%%s"
  end

  it "should replace %{key} with <%= key %>" do
    expect_to_replace "%{key}", "<%= key %>"
  end

  it "should replace %%{key} with %{key} (escaping)" do
    expect_to_replace '%%{key}', '%{key}'
  end

  it "should replace %%%{key} with %%{key} (escaping)" do
    expect_to_replace '%%%{key}', '%%{key}'
  end

  it "should replace %{key?} with <%= key? %>" do
    expect_to_replace "%{key?}", "<%= key? %>"
  end

  it "should replace %%{key?} with %{key?} (escaping)" do
    expect_to_replace '%%{key?}', '%{key?}'
  end

  it "should replace %%%{key?} with %%{key?} (escaping)" do
    expect_to_replace '%%%{key?}', '%%{key?}'
  end

  it "should replace %<key>s with <%= key %>" do
    expect_to_replace "%<key>s", "<%= key %>"
  end

  it "should replace %%<key>s with %<key>s (escaping)" do
    expect_to_replace "%%<key>s", "%<key>s"
  end

  it "should replace %%%<key>s with %%<key>s (escaping)" do
    expect_to_replace "%%%<key>s", "%%<key>s"
  end

  it "should replace %<key?>s with <%= key? %>" do
    expect_to_replace '%<key?>s', '<%= key? %>'
  end

  it "should replace %%<key?>s with %<key?>s (escaping)" do
    expect_to_replace '%%<key?>s', '%<key?>s'
  end

  it "should replace %%%<key?>s with %%<key?>s (escaping)" do
    expect_to_replace '%%%<key?>s', '%%<key?>s'
  end

  it "should not touch % that don't fit the shortcut sytax" do
    expect( Cmds.replace_shortcuts "50%" ).to eq "50%"
  end
end