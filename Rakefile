require 'thread'
require 'pastel'
require 'json'
require 'pp'
require 'tempfile'

require "bundler/gem_tasks"

Bundler.require

def configure_logger
  logger = Logger.new $stderr

  logger.level = case ENV['log']
  when 'debug'
    Logger::DEBUG
  when 'info'
    Logger::INFO
  when 'warn'
    Logger::WARN
  when 'error'
    Logger::ERROR
  else
    Logger::INFO
  end

  logger.formatter = proc do |severity, datetime, progname, msg|
    formatted = if Thread.current[:name]
      "[rake #{ severity } - #{ Thread.current[:name ] }] #{msg}\n"
    else
      "[rake #{ severity }] #{msg}\n"
    end

    if severity == 'DEBUG'
      formatted = Pastel.new.cyan(formatted)
    end

    formatted
  end
  logger
end

def log
  $logger ||= configure_logger
end

namespace :debug do
  desc "turn debug logging on"
  task :conf do
    ENV['log'] ||= 'debug'
    Cmds.enable_debug
  end

  task :proxy => :conf do
    Cmds.new("./test/questions.rb").proxy
  end

  namespace :capture do
    desc "capture with io-like input with debugging enabled"
    task :io_input => :conf do
      File.open "./test/lines.txt" do |f|
        Cmds.new("./test/echo_cmd.rb", input: f).capture
      end
    end
  end # ns capture

  namespace :stream do
    input = NRSER.dedent <<-BLOCK
      one
      two
      three
    BLOCK

    desc "output to blocks"
    task :blocks => :conf do
      Cmds.stream "ls" do |io|
        io.on_out do |line|
          puts "line: #{ line.inspect }"
        end
      end
    end

    desc "use a file as output"
    task :file_out => :conf do
      f = Tempfile.new "blah"
      Cmds.stream "echo here" do |io|
        io.out = f
      end

      f.rewind
      puts f.read
      f.close
      f.unlink
    end

    desc "input block value"
    task :value => :conf do
      Cmds.stream "wc -l" do
        input
      end
    end

    desc "input block hanlder"
    task :handler => :conf do
      Cmds.stream "wc -l" do |io|
        io.on_in do
        end
      end
    end

    desc "input io"
    task :io => :conf do
      File.open "./test/lines.txt" do |f|
        Cmds.stream("wc -l") { f }
      end
    end

    # this was a vauge idea that doesn't yet work, and may never
    # need a better understanding probably, so gonna punt for now
    desc "play with questions"
    task :questions => :conf do
      q = nil
      a = nil

      as = {
        "what is your name?" => 'nrser',
        "what is your quest?" => 'make this shit work somehow',
        "what is you favorite color?" => 'blue',
      }

      Cmds.stream "./test/questions.rb" do |io|
        io.on_out do |line|
          puts "on_out called"
          q = line
          puts "questions asked: #{ q }"
          a = as[q]
          raise "unknown question: #{ q }" unless a
          puts "setting answer to #{ a }..."
        end

        io.on_in do |f|
          puts "on_in called"
          if a
            puts "responding with #{ a }."
            f.write a
          else
            puts "no response ready."
          end
        end
      end
    end
  end # namespace stream
end # namespace debug
