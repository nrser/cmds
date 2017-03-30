require 'spec_helper'

describe "Cmds.tokenize_option" do
  context "default options" do
    it "handles integer value" do
      expect(Cmds.tokenize_option 'x', 1).to eq ["-x 1"]
      expect(Cmds.tokenize_option 'blah', 1).to eq ["--blah=1"]
    end
    
    it "handles string value" do
      expect(
        Cmds.tokenize_option 'x', "hey there!"
      ).to eq ["-x hey\\ there\\!"]
      
      expect(
        Cmds.tokenize_option 'blah', "hey there!"
      ).to eq ["--blah=hey\\ there\\!"]
    end
    
    it "emits just name token for true value" do
      expect(Cmds.tokenize_option 'x', true).to eq ["-x"]
      expect(Cmds.tokenize_option 'blah', true).to eq ["--blah"]
    end
    
    it "omits token for false value" do
      expect(Cmds.tokenize_option 'x', false).to eq []
      expect(Cmds.tokenize_option 'blah', false).to eq []
    end
    
    it "omits token for nil value" do
      expect(Cmds.tokenize_option 'x', nil).to eq []
      expect(Cmds.tokenize_option 'blah', nil).to eq []
    end
  end # default options
  
  describe "array_mode option" do
    context "array_mode default" do
      it "emits joined tokens for array value" do 
        expect(
          Cmds.tokenize_option 'b', [1, 2, 3]
        ).to eq ['-b 1,2,3']
        
        expect(
          Cmds.tokenize_option 'blah', [1, 2, 3]
        ).to eq ['--blah=1,2,3']
      end
      
      it "flattens nested arrays" do
        expect(
          Cmds.tokenize_option 'blah', [1, [:a, [:b, 3]]]
        ).to eq ['--blah=1,a,b,3']
      end
    end # default
    
    context "array_mode = :join" do
      def f(name, value)
        Cmds.tokenize_option name, value, array_mode: :join
      end
      
      it "emits joined tokens for array value" do 
        expect(f 'b', [1, 2, 3]).to eq ['-b 1,2,3']
        
        expect(f 'blah', [1, 2, 3]).to eq ['--blah=1,2,3']
      end
      
      it "flattens nested arrays" do
        expect(f 'blah', [1, [:a, [:b, 3]]]).to eq ['--blah=1,a,b,3']
      end
      
      describe "array_join_string option" do
        context "array_join_string = ', ' (has space in it)" do
          def f(name, value)
            Cmds.tokenize_option name, value,
              array_mode: :join,
              array_join_string: ', '
          end
          
          it "encodes the value as a single shell token" do
            tokens = f 'b', [1, 2, 3]
            expect(f 'b', [1, 2, 3]).to eq ['-b 1,\\ 2,\\ 3']
            
            expect(tokens[0].shellsplit).to eq ['-b', '1, 2, 3']
          end
        end
      end # array_join_string option
    end # array_mode = :join
    
    context "array_mode = :repeat" do
      def f(name, value)
        Cmds.tokenize_option name, value, array_mode: :repeat
      end
      
      it "emits multiple tokens for array value" do 
        expect(f 'b', [1, 2, 3]).to eq ['-b 1', '-b 2', '-b 3']
        expect(f 'blah', [1, 2, 3]).to eq ['--blah=1', '--blah=2', '--blah=3']
      end
      
      it "flattens nested arrays" do
        expect(f 'blah', [1, [:a, [:b, 3]]]).
          to eq ['--blah=1', '--blah=a', '--blah=b', '--blah=3']
      end
    end # array_mode = :repeat
    
    context "array_mode = :json" do
      def f(name, value)
        Cmds.tokenize_option name, value, array_mode: :json
      end
      
      it "emits single json token for array value" do
        short_tokens = f 'b', [1, 2, 3]
        
        expect(short_tokens.length).to be 1
        expect(JSON.load short_tokens[0].shellsplit[1]).to eq [1, 2, 3]
      end
    end # array_mode = :json
    
  end # array_mode option

end # .tokenize_option
