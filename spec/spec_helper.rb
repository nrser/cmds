require 'pathname'

ROOT = 

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'cmds'

def argv result
  expect(result.ok?).to be true
  JSON.load(result.out)['ARGV']
end

def expect_argv result
  expect(argv(result))
end

# rspec uses StringIO for stdout and stderr, which spawn doesn't like.
# this function swaps in tempfiles for $stdout and $stderr and returns
# there outputs as strings.
def temp_outs
  # save ref to $stdout and $stderr
  prev_stdout, prev_stderr = $stdout, $stderr

  # create templfiles for out and err
  out_f, err_f = ['out', 'err'].map {|s|
    Tempfile.new "rspec_std#{ s }"
  }

  # assign those to $stdout and $stderr
  $stdout, $stderr = out_f, err_f

  # run the provided block
  yield

  # get the out and err strings and clean up
  out, err = [out_f, err_f].map {|f|
    f.rewind
    str = f.read
    f.close
    f.unlink
    str
  }

  # swap back to the old $stdout and $stderr
  $stdout, $stderr = prev_stdout, prev_stderr

  # return the output strings
  [out, err]
end # temp_out

# gets a `Cmds` instance pointing to the `test/echo_cmd.rb` script
def echo_cmd
  Cmds.new "./test/echo_cmd.rb"
end

shared_examples "ok" do
  it "should be ok" do
    expect( result.ok? ).to be true
  end

  it "should have empty err" do
    expect( result.err ).to eq ""
  end
end # ok
