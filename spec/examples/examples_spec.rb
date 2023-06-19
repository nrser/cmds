require 'spec_helper'

describe 'Examples' do
  context 'combine template and shell interpolation' do
    it 'works with ${<%= ... %>}' do
      expect(
        Cmds!('echo ${<%= var_name %>}', var_name: 'PWD').out.chomp
      ).to eq ENV['PWD']
    end

    it 'works with ${%{ ... }}' do
      expect(
        Cmds!('echo ${%{var_name}}', var_name: 'PWD').out.chomp
      ).to eq ENV['PWD']
    end
  end
end # Examples
