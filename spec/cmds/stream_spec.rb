require 'spec_helper'

describe "Cmds::stream" do
  times = 5

  it "writes to $stdout and $stderr by default" do
    expect {
      Cmds.stream './test/tick.rb <%= times %>', times: times
    }.to output(times.times.map{|_| "#{_}\n"}.join).to_stdout
  end

  it "writes to blocks" do
    out = StringIO.new
    out_count = 0
    err = StringIO.new
    err_count = 0
    Cmds.stream './test/tick.rb <%= times %>', times: times do |on|
      # right now this does NOT happen in the main thread
      # TODO: it should, the other threads should just pass shit back to
      # the main one
      on.out do |line|
        out_count += 1
      end

      on.err do |line|
        err_count += 1
      end
    end
    expect(out_count).to eq times
    expect(err_count).to eq 0
  end
end # Cmds::stream