require 'spec_helper'

describe "Cmds.prepare" do
  it "should work with a keyword substitutions" do
    expect(
      Cmds.prepare "psql <%= opts %> <%= database %> < <%= filepath %>",
        database: "blah",
        filepath: "/where ever/it/is.psql",
        opts: {
          username: "bingo bob",
          host: "localhost",
          port: 12345,
        }
    ).to eq 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  end
  
  it "should work with a keyword substitutions with String keys" do
    expect(
      # NOTE  since we use **kwds in #prepare which only accepts symbol keys,
      #       have to load kwds with string keys in through Cmds.new
      Cmds.new(
        "psql <%= opts %> <%= database %> < <%= filepath %>", {
          kwds: {
            'database' => "blah",
            'filepath' => "/where ever/it/is.psql",
            'opts' => {
              username: "bingo bob",
              host: "localhost",
              port: 12345,
            }
          }
        }
      ).prepare
    ).to eq 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  end

  it "should work with positional substitutions" do
    expect(
      Cmds.prepare "psql <%= arg %> <%= arg %> < <%= arg %>",
        {
          username: "bingo bob",
          host: "localhost",
          port: 12345,
        },
        "blah",
        "/where ever/it/is.psql"
    ).to eq 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  end

  it "should work with no arguments" do
    expect(
      Cmds.prepare "blah <% if true %>blow<% end %>"
    ).to eq "blah blow"
  end
  
  it "should work with positional and keyword substitutions" do
    expect(
      Cmds.prepare "blah <%= arg %> <%= y %>", "ex", y: "why"
    ).to eq "blah ex why"
  end
  
  it "should work with direct reference to args" do
    expect(
      Cmds.prepare "psql <%= @args[1] %> <%= @args[0] %> < <%= @args[2] %>",
        "blah",
        {
          username: "bingo bob",
          host: "localhost",
          port: 12345,
        },
        "/where ever/it/is.psql"
    ).to eq 'psql --host=localhost --port=12345 --username=bingo\ bob blah < /where\ ever/it/is.psql'
  end

  context "if statement" do
    let(:tpl) {
      <<-BLOCK
        defaults
        <% if current_host? %>
          -currentHost <%= current_host %>
        <% end %>
        export <%= domain %> <%= filepath %>
      BLOCK
    }

    it "should work when value is present" do
      expect(
        Cmds.prepare tpl, current_host: 'xyz',
                          domain: 'com.nrser.blah',
                          filepath: '/tmp/export.plist'
      ).to eq "defaults -currentHost xyz export com.nrser.blah /tmp/export.plist"
    end

    it "should work when value is missing" do
      expect(
        Cmds.prepare tpl, domain: 'com.nrser.blah',
                          filepath: '/tmp/export.plist'
      ).to eq "defaults export com.nrser.blah /tmp/export.plist"
    end
  end

  context "each statement" do
    let(:tpl) {
      <<-BLOCK
        defaults write <%= domain %> <%= key %> -dict
        <% values.each do |key, value| %>
          <%= key %> <%= value %>
        <% end %>
      BLOCK
    }

    it "should loop correctly and escape values" do
      expect(
        Cmds.prepare tpl, domain: "com.nrser.blah",
                          key: 'k',
                          values: {x: '<ex>', y: 'why'}
      ).to eq "defaults write com.nrser.blah k -dict x \\<ex\\> y why"
    end
  end

  context "optional subs" do
    let(:tpl) {
      <<-BLOCK
        blah <%= x? %> <%= y? %> <%= z? %>
      BLOCK
    }

    it "should omit the missing subs" do
      expect(Cmds.prepare tpl, x: "ex", z: "zee").to eq "blah ex zee"
    end
    
    it "should omit a sub if it's value is false" do
      expect(Cmds.prepare "%{x?}", x: false).to eq ""
    end
  end

  context "errors" do
    it "should error when a kwarg is missing" do
      expect {
        Cmds.prepare "a <%= b %> <%= c %>", b: 'bee!'
      }.to raise_error KeyError
    end

    it "should error when an arg is missing" do
      expect {
        Cmds.prepare "a <%= arg %> <%= arg %>", 'bee!'
      }.to raise_error IndexError
    end
  end # errors

  context "shortcuts" do
    it "should replace %s" do
      expect(
        Cmds.prepare "./test/echo_cmd.rb %s", "hello world!"
      ).to eq './test/echo_cmd.rb hello\ world\!'
    end

    it "should replace %{key}" do
      expect(
        Cmds.prepare "./test/echo_cmd.rb %{key}", key: "hello world!"
      ).to eq './test/echo_cmd.rb hello\ world\!'
    end

    it "should replace %<key>s" do
      expect(
        Cmds.prepare "./test/echo_cmd.rb %<key>s", key: "hello world!"
      ).to eq './test/echo_cmd.rb hello\ world\!'
    end
    
    context "% proceeded by =" do
      it "handles %s" do
        expect(
          Cmds.prepare "X=%s ./test/echo_cmd.rb", "hello world!"
        ).to eq 'X=hello\ world\! ./test/echo_cmd.rb'
        
        expect(
          Cmds.prepare "./test/echo_cmd.rb --x=%s", "hello world!"
        ).to eq './test/echo_cmd.rb --x=hello\ world\!'
      end
      
      it "handles %{key}" do
        expect(
          Cmds.prepare "X=%{key} ./test/echo_cmd.rb", key: "hello world!"
        ).to eq 'X=hello\ world\! ./test/echo_cmd.rb'
        
        expect(
          Cmds.prepare "./test/echo_cmd.rb --x=%<key>s", key: "hello world!"
        ).to eq './test/echo_cmd.rb --x=hello\ world\!'
      end
      
      it "handles %<key>s" do
        expect(
          Cmds.prepare "X=%<key>s ./test/echo_cmd.rb", key: "hello world!"
        ).to eq 'X=hello\ world\! ./test/echo_cmd.rb'
        
        expect(
          Cmds.prepare "./test/echo_cmd.rb --x=%<key>s", key: "hello world!"
        ).to eq './test/echo_cmd.rb --x=hello\ world\!'
      end
    end # % proceeded by =
  end # shortcuts
  
  context "tokenize multiple args as shell list" do
    it "should expand args as space-separated list" do
      expect(
        Cmds.prepare "git add <%= *args %>", "x", "y", "z"
      ).to eq "git add x y z"
    end
  end
  
  describe "options with list values" do
    
    context "default behavior (:join)" do
      it "outputs a comma-separated list" do
        expect(
          Cmds.prepare 'blah <%= opts %>', opts: {list: ['a', 'b', 'see']}
        ).to eq 'blah --list=a,b,see'
      end
    end
    
    context "specify :repeat behavior" do
      it "outputs repeated options" do
        expect(
          Cmds.prepare 'blah <%= opts %>',
            opts: { list: ['a', 'b', 'see'] } {
            { array_mode: :repeat }
          }
        ).to eq 'blah --list=a --list=b --list=see'
      end
    end
    
    context "specify :json behavior" do
      it "outputs JSON-encoded options" do
        expect(
          Cmds.prepare 'blah <%= opts %>',
            opts: { list: ['a', 'b', 'see'] } {{ array_mode: :json }}
        ).to eq %{blah --list='["a","b","see"]'}
      end
      
      it "handles single quotes in the string" do
        expect(
          Cmds.prepare 'blah <%= opts %>',
            opts: { list: ["you're the best"] } {{ array_mode: :json }}
        ).to eq %{blah --list='["you'"'"'re the best"]'}
        
        
        expect(
          Cmds.new(
            'blah <%= opts %>',
            kwds: {
              opts: { list: ["you're the best"] }
            },
            array_mode: :json,
          ).prepare
        ).to eq %{blah --list='["you'"'"'re the best"]'}
      end
    end
    
  end # "options with list values"
  
  
  describe %{space-separated "long" opts} do
    
    it %{should work when `long_opt_separator: ' '` passed to Cmds.new} do
      expect(
        Cmds.new(
          'blah <%= opts %>',
          kwds: {
            opts: {
              file: 'some/path.rb'
            }
          },
          long_opt_separator: ' '
        ).prepare
      ).to eq %{blah --file some/path.rb}
    end
    
  end # "space-separated long options"
  
  
  describe "hash opt values" do
    
    it do
      expect(
        Cmds.prepare(
          'docker build <%= opts %>',
          opts: {
            'build-arg' => {
              'from_image' => 'blah:0.1.2',
              'yarn_version' => '1.3.2',
            }
          }
        ) {{
          array_mode: :repeat,
          long_opt_separator: ' ',
          hash_join_string: '=',
        }}
      ).to eq %{docker build --build-arg from_image\\=blah:0.1.2 --build-arg yarn_version\\=1.3.2}
    end
    
  end # "hash opt values"
  
  
  
end # ::prepare
