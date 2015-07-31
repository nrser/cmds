require "bundler/gem_tasks"

Bundler.require

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
