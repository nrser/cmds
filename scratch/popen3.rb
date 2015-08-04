#!/usr/bin/env ruby

require 'open3'
require 'thread'
require 'pty'

master, slave = PTY.open

Open3.popen3("./test/tick.rb 10") do |stdin, stdout, stderr, thread|
  {
    stdout => ["out", $stdout],
    stderr => ["err", $stderr],
  }.each do |src, (name, dest)|

    puts "starting #{ name } thread"
    Thread.new do
      loop do
        puts "getting #{ name } line..."
        line = src.gets
        puts "got #{ name } line."
        if line.nil?
          puts "#{ name } done, breaking."
          break
        else
          puts "wiriting #{ line.bytesize } bytes to #{ name }."
          dest.puts line
        end
      end
    end
  end

  thread.join
end