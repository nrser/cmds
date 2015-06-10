#!/usr/bin/env ruby

require 'json'

# this script echos the command that invoked it back as a 
# JSON structure for testing

argv = ARGV.clone

data = {
  '$0' => $0,
  'ARGV' => argv,
}

puts JSON.pretty_generate(data)