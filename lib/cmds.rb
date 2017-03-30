# stdlib
require 'shellwords'
require 'open3'
require 'thread'

# deps
require 'nrser'

# project
require "cmds/capture"
require "cmds/debug"
require "cmds/erb_context"
require "cmds/io_handler"
require "cmds/pipe"
require "cmds/result"
require "cmds/shell_eruby"
require "cmds/stream"
require "cmds/sugar"
require "cmds/util"
require "cmds/version"

class Cmds
  attr_reader :template
  
  attr_reader :args
  
  attr_reader :kwds
  
  attr_reader :input
  
  attr_reader :assert
  
  attr_reader :env
  
  # attr_reader :format

  def initialize template, opts = {}
    Cmds.debug "Cmds constructed",
      template: template,
      options: opts

    @template = template
    @args = opts[:args] || []
    @kwds = opts[:kwds] || {}
    @input = opts[:input] || nil
    @assert = opts[:assert] || false
    @env = opts[:env] || {}
    @format = opts[:format] || :squish
  end # #initialize
end