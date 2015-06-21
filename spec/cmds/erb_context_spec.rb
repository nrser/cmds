require 'spec_helper'

describe Cmds::ERBContext do
  let(:tpl) {
    <<-BLOCK
      defaults
      <% if current_host? %>
        -currentHost <%= current_host %>
      <% end %>
      export <%= domain %> <%= filepath %>
    BLOCK
  }

  def get_result tpl, bnd
    NRSER.squish ERB.new(tpl).result(bnd.get_binding)
  end

  it "should work" do
    bnd = Cmds::ERBContext.new [], current_host: 'xyz', domain: 'com.nrser.blah', filepath: '/tmp/export.plist'

    expect(get_result tpl, bnd).to eq "defaults -currentHost xyz export com.nrser.blah /tmp/export.plist"
  end
end