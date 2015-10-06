require 'pathname'
require 'json'
require 'tempfile'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'cmds'

ECHO_CMD = "./test/echo_cmd.rb"

def echo_cmd_data result
  expect( result.cmd ).to start_with ECHO_CMD
  expect( result ).to be_instance_of Cmds::Result
  expect( result.ok? ).to be true
  data = JSON.load result.out
  expect( data ).to be_instance_of Hash
  data
end

def echo_cmd_key result, key
  data = echo_cmd_data result
  expect( data.key? key ).to be true
  data[key]
end

def echo_cmd_argv result
  echo_cmd_key result, 'ARGV'
end

def echo_cmd_stdin result
  echo_cmd_key result, 'stdin'
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

def expect_map method, map
  map.each do |input, output|
    expect( method.call *input ).to eq output
  end
end

shared_examples "ok" do
  it "should be ok" do
    expect( result.ok? ).to be true
  end

  it "should have empty err" do
    expect( result.err ).to eq ""
  end
end # ok
