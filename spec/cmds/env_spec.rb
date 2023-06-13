require 'spec_helper'

describe 'Cmds ENV vars' do
  r_echo_cmd = %(ruby -e "puts ENV['BLAH']")

  def r_echo key, **options
    Cmds.new(%(ruby -e "puts ENV['#{key}']"), **options).chomp!
  end

  it 'sets basic (path-like) string ENV var' do
    cmd = Cmds.new r_echo_cmd, env: { BLAH: 'x:y:z' }
    expect(cmd.chomp!).to eq 'x:y:z'
  end

  it 'sets a string with spaces in it correctly' do
    cmd = Cmds.new r_echo_cmd, env: { BLAH: 'hey there' }
    expect(cmd.chomp!).to eq 'hey there'
  end

  it 'accepts string keys' do
    cmd = Cmds.new r_echo_cmd, env: {
      'BLAH' => [
        '/usr/local/bin',
        '/usr/bin',
        '/bin'
      ].join(':')
    }
    expect(cmd.chomp!).to eq '/usr/local/bin:/usr/bin:/bin'
  end

  # Want to play around / test out what happens with ENV inheritance...
  describe 'ENV inheritance', :env_inheritance do
    # Cmds::Debug.on

    context 'random parent and child value, set in parent ENV' do
      key = 'BLAH'

      before :each do
        @rand = Random.rand.to_s
        @parent_value = "parent_#{@rand}"
        @child_value = "child_#{@rand}"
        ENV[key] = @parent_value
      end

      after :each do
        ENV.delete key
      end

      let :cmd_options do
        {}
      end

      subject do
        r_echo key, **cmd_options
      end

      it 'should have ENV[key] set to @parent_value' do
        expect(ENV[key]).to eq @parent_value
      end

      describe 'no env provided to cmd' do
        it 'has ENV[key] set to @parent_value in child' do
          expect(r_echo(key)).to eq @parent_value
        end
      end

      describe 'empty env' do
        it 'should have ENV[key] set to @parent_value in child' do
          expect(r_echo(key, env: {})).to eq @parent_value
        end
      end

      describe 'unsetenv_others: true' do
        it 'should have ENV[key] unset in child' do
          expect(r_echo(key,
                        unsetenv_others: true)).to eq ''
        end
      end

      describe 'env: { key => child_value }' do
        it 'should have ENV[key] set to @child_value in child' do
          expect(
            r_echo(key, env: { key => @child_value })
          ).to eq @child_value
        end
      end
    end
  end
end
