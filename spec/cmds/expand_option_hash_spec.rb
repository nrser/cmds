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
    it "handles nil value" do
      expect(Cmds.expand_option_hash blah: nil).to eq "--blah"
    end

    it "handles a simple value" do
      expect(Cmds.expand_option_hash blah: 1).to eq "--blah=1"
    end

    it "handles an array value" do
      expect(Cmds.expand_option_hash blah: [1, 2, 3]).to eq "--blah=1 --blah=2 --blah=3"
    end
  end # one longer key

  context "multiple longer keys" do
    it "order expansion by key" do
      expect(Cmds.expand_option_hash bob: 2, al: 1, cat: 3).to eq "--al=1 --bob=2 --cat=3"
    end
  end # multiple longer keys

  it "handles a mess of stuff" do
    expect(
      Cmds.expand_option_hash d:    1,
                              blah: "blow", 
                              cat:  nil, 
                              x:    ['m', 'e',]
    ).to eq "--blah=blow --cat -d 1 -x m -x e"
  end

  it "escapes paths" do
    expect(
      Cmds.expand_option_hash path: "/some folder/some where",
                              p:    "maybe ov/er here..."
    ).to eq '-p maybe\ ov/er\ here... --path=/some\ folder/some\ where'
  end

end # ::expand_option_hash_spec
