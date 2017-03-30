require 'spec_helper'

describe "Cmds::sub" do
  it "should work with a keyword substitutions" do
    expect(
      Cmds.sub "psql <%= opts %> <%= database %> < <%= filepath %>",
        [],
        database: "blah",
        filepath: "/where ever/it/is.psql",
        opts: {
          username: "bingo bob",
          host: "localhost",
          port: 12345,
        }
    ).to eq 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  end

  it "should work with positional substitutions" do
    expect(
      Cmds.sub "psql <%= arg %> <%= arg %> < <%= arg %>", [
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

  it "should work with no arguments" do
    expect(
      Cmds.sub "blah <% if true %>blow<% end %>"
    ).to eq "blah blow"
  end

  it "should work with positional and keyword substitutions" do
    expect(
      Cmds.sub "blah <%= arg %> <%= y %>", ["ex"], y: "why"
    ).to eq "blah ex why"
  end

  it "should work with direct reference to args" do
    expect(
      Cmds.sub "psql <%= @args[2] %> <%= @args[0] %> < <%= @args[1] %>", [
        "blah",
        "/where ever/it/is.psql",
        {
          username: "bingo bob",
          host: "localhost",
          port: 12345,
        },
      ]
    ).to eq 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  end

  context "if statement" do
    let(:tpl) {
      <<-BLOCK
        defaults
        <% if current_host? %>
          -currentHost <%= current_host %>
        <% end %>
        export <%= domain %> <%= filepath %>
      BLOCK
    }

    it "should work when value is present" do
      expect(
        Cmds.sub tpl, [], current_host: 'xyz',
                          domain: 'com.nrser.blah',
                          filepath: '/tmp/export.plist'
      ).to eq "defaults -currentHost xyz export com.nrser.blah /tmp/export.plist"
    end

    it "should work when value is missing" do
      expect(
        Cmds.sub tpl, [], domain: 'com.nrser.blah',
                          filepath: '/tmp/export.plist'
      ).to eq "defaults export com.nrser.blah /tmp/export.plist"
    end
  end

  context "each statement" do
    let(:tpl) {
      <<-BLOCK
        defaults write <%= domain %> <%= key %> -dict
        <% values.each do |key, value| %>
          <%= key %> <%= value %>
        <% end %>
      BLOCK
    }

    it "should loop correctly and escape values" do
      expect(
        Cmds.sub tpl, [], domain: "com.nrser.blah",
                          key: 'k',
                          values: {x: '<ex>', y: 'why'}
      ).to eq "defaults write com.nrser.blah k -dict x \\<ex\\> y why"
    end
  end

  context "optional subs" do
    let(:tpl) {
      <<-BLOCK
        blah <%= x? %> <%= y? %> <%= z? %>
      BLOCK
    }

    it "should omit the missing subs" do
      expect(Cmds.sub tpl, [], x: "ex", z: "zee").to eq "blah ex zee"
    end
    
    # it "should omit a sub if it's value is false" do
    #   expect(Cmds.sub "%{x?}", [], x: false).to eq ""
    # end
  end

  context "errors" do
    it "should raise TypeError if subs in not an array or a hash" do
      expect{Cmds.sub "a <%= b %> <%= c %>", "dee!"}.to raise_error TypeError
    end

    it "should error when a kwarg is missing" do
      expect {
        Cmds.sub "a <%= b %> <%= c %>", [], b: 'bee!'
      }.to raise_error KeyError
    end

    it "should error when an arg is missing" do
      expect {
        Cmds.sub "a <%= arg %> <%= arg %>", ['bee!']
      }.to raise_error IndexError
    end

    it "should error when more than two args are passed" do
      expect {
        Cmds.sub "blah", 1, 2, 3
      }.to raise_error ArgumentError
    end
  end # errors

  context "shortcuts" do
    it "should replace %s" do
      expect(
        Cmds.sub "./test/echo_cmd.rb %s", ["hello world!"]
      ).to eq './test/echo_cmd.rb hello\ world\!'
    end

    it "should replace %{key}" do
      expect(
        Cmds.sub "./test/echo_cmd.rb %{key}", [], key: "hello world!"
      ).to eq './test/echo_cmd.rb hello\ world\!'
    end

    it "should replace %<key>s" do
      expect(
        Cmds.sub "./test/echo_cmd.rb %<key>s", [], key: "hello world!"
      ).to eq './test/echo_cmd.rb hello\ world\!'
    end
  end # shortcuts
end # ::sub
