require 'thread'
require 'pastel'

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
      "[#{ severity } - #{ Thread.current[:name ] }] #{msg}\n"
    else
      "[#{ severity }] #{msg}\n"
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
    Cmds.configure_logger
  end

  namespace :stream do
    input = NRSER.dedent <<-BLOCK
      one
      two
      three
    BLOCK

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
      Cmds.stream "./test/questions.rb" do |io|
        $stdin
      end
    end

    desc "try to get select to work for a proxy"
    task :proxy_select => :conf do
      require 'pty'

      to_write = nil

      as = {
        "what is your name?" => 'nrser',
        "what is your quest?" => 'make this shit work somehow',
        "what is you favorite color?" => 'blue',
      }

      # PTY.spawn "./test/questions.rb", in: $stdin, out: $stdout
      PTY.spawn "./test/questions.rb" do |stdout, stdin, pid|
        loop do
          # puts "selecting..."
          reads, writes, errors = IO.select [stdout], [stdin]
          # puts "reads: #{ reads.inspect }"
          # puts "writes: #{ writes.inspect }"
          # puts "errors: #{ errors.inspect }"

          if reads[0]
            puts "handling stdout"
            line = reads[0].gets
            puts "line: #{ line.inspect }"
            if line.nil?
              puts "output done, breaking"
              break
            else
              q = line.chomp
              to_write = as[q]
              puts "stdout: #{ line }"
            end
          end

          if writes[0]
            # puts "handling stdin"
            unless to_write.nil?
              stdin.write to_write
            end
          end
        end # loop
      end
    end

    desc "try to get threads to work for a proxy"
    task :thread_proxy => :conf do
      require 'pty'

      as = {
        "what is your name?" => 'nrser',
        "what is your quest?" => 'make this shit work somehow',
        "what is you favorite color?" => 'blue',
      }

      # PTY.spawn "./test/questions.rb", in: $stdin, out: $stdout
      PTY.spawn "./test/questions.rb" do |stdout, stdin, pid|

        to_write = Queue.new

        stdout_thread = Thread.new do
          puts "starting stout thread"
          loop do
            line = stdout.gets
            puts "read line #{ line.inspect }"
            if line.nil?
              puts "nil line, breaking"
              to_write << nil
              break
              # if stdout.closed?
              #   puts "stdout closed, pushing nil"
              #   to_write << nil
              #   break
              # else
              #   puts "stdout open, continuing"
              # end
            else
              puts "answering line #{ line.inspect }"
              q = line.chomp
              a = as[q]
              if a.nil?
                puts "found no answer for #{ q.inspect }"
              else
                puts "pushing answer #{ a.inspect }"
                to_write << a
              end
              puts "stdout: #{ line }"
            end
          end
        end

        stdin_thread = Thread.new do
          puts "starting stdin thread"
          loop do
            puts "input blocking on pop"
            a = to_write.pop
            if a.nil?
              puts "nil pop, breaking"
              break
            else
              puts "writing #{ a.inspect }"
              stdin.puts a
            end
          end
        end

        stdout_thread.join
        stdin_thread.join
      end
    end

    desc "blah"
    task :pty_proxy => :conf do
      require 'pty'

      out_master, out_slave = PTY.open
      err_master, err_slave = PTY.open

      in_read, in_write = IO.pipe


      pid = spawn "./test/questions.rb",  out: out_slave,
                                          err: err_slave,
                                          in: in_read

      out_slave.close
      err_slave.close
      in_read.close

      inputs = [
        "nrser",
        "blah",
        "blue",
      ]

      log.debug "starting loop..."
      loop do
        if in_write.closed?
          reads, writes = IO.select [out_master, err_master]
        else
          reads, writes = IO.select [out_master, err_master], [in_write]
        end

        log.debug NRSER.dedent <<-BLOCK
          ready:
            reads: #{ reads.inspect }
            writes: #{ writes.inspect }
        BLOCK

        reads.each do |read|
          line = read.gets
          if line.nil?
            log.debug "#read { read.inspect }: nil line"
          else
            log.debug "#read { read.inspect }: #{ line }"
          end
        end

        if writes[0]
          write = writes[0]
          input = inputs.pop
          if input.nil?
            puts "out of input, closing write"
            write.close
          else
            puts "writing #{ input.inspect }"
            write.write input
          end
        end
        break
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
