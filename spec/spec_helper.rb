$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'cmds'

def argv result
  expect(result.ok?).to be true
  JSON.load(result.out)['ARGV']
end

def expect_argv result
  expect(argv(result))
end

shared_examples "ok" do
  it "should be ok" do
    expect( result.ok? ).to be true
  end

  it "should have empty err" do
    expect( result.err ).to eq ""
  end
end # ok
