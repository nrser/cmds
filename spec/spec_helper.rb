$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'cmds'

def argv result
  expect(result.ok?).to be true
  JSON.load(result.out)['ARGV']
end

def expect_argv result
  expect(argv(result))
end

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

shared_examples "ok" do
  it "should be ok" do
    expect( result.ok? ).to be true
  end

  it "should have empty err" do
    expect( result.err ).to eq ""
  end
end # ok
