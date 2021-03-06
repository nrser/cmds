require 'spec_helper'

describe 'Cmds#stream' do
  let(:times) { 5 }

  it "writes to $stdout and $stderr by default" do
    out, err = temp_outs do
      Cmds.new('./test/tick.rb <%= times %>').stream times: times
    end

    expect(out).to eq times.times.map{|_| "#{_}\n"}.join
    expect(err).to eq ''
  end

  it "handles writes in blocks" do
    out_count = 0
    err_count = 0
    Cmds.new('./test/tick.rb <%= times %>').stream(times: times) do |io|
      io.on_out do |line|
        out_count += 1
      end

      io.on_err do |line|
        err_count += 1
      end
    end
    expect(out_count).to eq times
    expect(err_count).to eq 0
  end

  context "input" do
    it "accepts string value input from a block" do

      out, err = temp_outs do
        Cmds.new("wc -l").stream do
          <<-BLOCK
            one
            two
            three
          BLOCK
        end
      end

      expect(out).to match /^\s*3\n$/
      expect(err).to eq ''
    end

    it "accepts stream value input from a block" do
      out, err = temp_outs do
        Cmds.new("wc -l").stream do
          File.open "./test/lines.txt"
        end
      end

      expect(out).to match /^\s*3\n$/
    end
  end # input
  
  it "returns the exit status" do
    expect(Cmds.new('true').stream).to be 0
    expect(Cmds.new('false').stream).to be 1
  end
end # Cmds#stream

describe 'Cmds#stream!' do
  it "raises when exit code is not 0" do
    expect { Cmds.new('false').stream! }.to raise_error SystemCallError
  end
end
