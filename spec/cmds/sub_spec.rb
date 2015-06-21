require 'spec_helper'

describe "Cmds::sub" do
  it "should work with a hash" do
    expect(
      Cmds.sub "psql <%= opts %> <%= database %> < <%= filepath %>",
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
        Cmds.sub tpl, current_host: 'xyz',
                      domain: 'com.nrser.blah',
                      filepath: '/tmp/export.plist'
      ).to eq "defaults -currentHost xyz export com.nrser.blah /tmp/export.plist"
    end

    it "should work when value is missing" do
      expect(
        Cmds.sub tpl, domain: 'com.nrser.blah',
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

    it "should this even work?!" do
      expect(
        Cmds.sub tpl, domain: "com.nrser.blah",
                      key: 'k',
                      values: {x: 'ex', y: 'why'}
      ).to eq "defaults write com.nrser.blah k -dict x ex y why"
    end
  end

  it "should raise TypeError if subs in not an array or a hash" do
    expect{Cmds.sub "a <%= b %> <%= c %>", "dee!"}.to raise_error TypeError
  end

  it "should error when a kwarg is missing" do
    expect {
      Cmds.sub "a <%= b %> <%= c %>", b: 'bee!'
    }.to raise_error KeyError
  end

  it "should error when an arg is missing" do
    expect {
      Cmds.sub "a <%= arg %> <%= arg %>", ['bee!']
    }.to raise_error IndexError
  end
end # ::sub