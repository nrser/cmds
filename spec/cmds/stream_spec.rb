require 'spec_helper'

describe "Cmds::stream" do
  let(:times) { 5 }

  # rspec uses StringIO for stdout and stderr, which spawn doesn't like
  def temp_outs
    prev_stdout = $stdout
    prev_stderr = $stderr
    out_f = Tempfile.new "rspec_stdout"
    err_f = Tempfile.new "rspec_stderr"
    $stdout = out_f
    $stderr = err_f
    yield
    out_f.rewind
    out = out_f.read
    err_f.rewind
    err = err_f.read
    [out_f, err_f].each {|f|
      f.close
      f.unlink
    }
    $stdout = prev_stdout
    $stderr = prev_stderr
    [out, err]
  end

  it "writes to $stdout and $stderr by default" do
    out, err = temp_outs do
      Cmds.stream './test/tick.rb <%= times %>', times: times
    end

    expect(out).to eq times.times.map{|_| "#{_}\n"}.join
    expect(err).to eq ''
  end

  it "handles writes in blocks" do
    out_count = 0
    err_count = 0
    Cmds.stream './test/tick.rb <%= times %>', times: times do |io|
      io.on_out do |line|
        out_count += 1
      end

      io.on_err do |line|
        err_count += 1
      end

      nil
    end
    expect(out_count).to eq times
    expect(err_count).to eq 0
  end

  context "input" do
    it "accepts value input from a block" do

      out, err = temp_outs do
        Cmds.stream "wc -l" do
          <<-BLOCK
            one
            two
            three
          BLOCK
        end
      end

      expect(out).to match /^\s+3\n$/
      expect(err).to eq ''
    end

    it "accepts stream input from a block" do
      out, err = temp_outs do
        Cmds.stream "wc -l" do
          File.open "./test/lines.txt"
        end
      end

      expect(out).to match /^\s+3\n$/
    end
  end
end # Cmds::stream