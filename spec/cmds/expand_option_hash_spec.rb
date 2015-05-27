require 'spec_helper'

describe "Cmds.expand_option_hash_spec" do

  context "one single char key" do
    it "handles nil value" do
      expect(Cmds.expand_option_hash x: nil).to eq "-x"
    end

    it "handles simple value" do
      expect(Cmds.expand_option_hash x: 1).to eq "-x 1"
    end

    it "handles array value" do
      expect(Cmds.expand_option_hash x: [1, 2, 3]).to eq "-x 1 -x 2 -x 3"
    end
  end # single char key

  context "multiple single char keys" do
    it "order expansion by key" do
      expect(Cmds.expand_option_hash b: 2, a: 1, c: 3).to eq "-a 1 -b 2 -c 3"
    end
  end # multiple single char keys

  context "one longer key" do
    it "handled nil value" do
      expect(Cmds.expand_option_hash blah: nil).to eq "--blah"
    end
  end # one longer key

end # ::expand_option_hash_spec
