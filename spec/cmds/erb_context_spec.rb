require 'spec_helper'

describe Cmds::ERBContext do
  let(:tpl) do
    <<-BLOCK
      defaults
      <% if current_host? %>
        -currentHost <%= current_host %>
      <% end %>
      export <%= domain %> <%= filepath %>
    BLOCK
  end

  def get_result(tpl, context)
    # NOTE: This *used* to use {ERB.new}, but that stopped working in Ruby
    #       2.4+ with a weird
    #
    #           uninitialized constant Cmds::ERBContext::String
    #
    #       message... https://travis-ci.org/nrser/cmds/jobs/347910522
    #
    #       This doesn't matter, because we use {ERubis}, and that still works,
    #       so switched to that here...
    #
    Cmds::Text.squish Cmds::ShellEruby.new(tpl).result(context.get_binding)
  end

  it 'should work' do
    context = Cmds::ERBContext.new(
      [],
      {
        current_host: 'xyz',
        domain: 'com.nrser.blah',
        filepath: '/tmp/export.plist'
      }
    )

    expect(
      get_result(tpl, context)
    ).to eq 'defaults -currentHost xyz export com.nrser.blah /tmp/export.plist'
  end
end
