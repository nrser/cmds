require 'spec_helper'

describe 'Cmds::replace_shortcuts' do
  meth = Cmds.method(:replace_shortcuts)
  
  it "should replace %s with <%= arg %>" do
    expect_map meth, {
      ["%s"]              => "<%= arg %>",
      ["blah %s"]         => "blah <%= arg %>",
      ["%s blah"]         => "<%= arg %> blah",
      ["blah\n%s\nblah"]  => "blah\n<%= arg %>\nblah",
      ["%s %s"]           => "<%= arg %> <%= arg %>",
    }
  end
  
  it "should replace %%s with %s (escaping)" do
    expect_map meth, {
      ["%%s"]              => "%s",
      ["blah %%s"]         => "blah %s",
      ["%%s blah"]         => "%s blah",
      ["blah\n%%s\nblah"]  => "blah\n%s\nblah",
      ["%%s %%s"]          => "%s %s",
      ["%%%s"]             => "%%s",
    }
  end
   
  it "should replace %{key} with <%= key %>" do
    expect_map meth, {
      ["%{key}"]              => "<%= key %>",
      ["blah %{key}"]         => "blah <%= key %>",
      ["%{key} blah"]         => "<%= key %> blah",
      ["blah\n%{key}\nblah"]  => "blah\n<%= key %>\nblah",
      ["%{x} %{y}"]           => "<%= x %> <%= y %>",
    }
  end
  
  it "should replace %{key?} with <%= key? %>" do
    expect_map meth, {
      ["%{key?}"]              => "<%= key? %>",
      ["blah %{key?}"]         => "blah <%= key? %>",
      ["%{key?} blah"]         => "<%= key? %> blah",
      ["blah\n%{key?}\nblah"]  => "blah\n<%= key? %>\nblah",
      ["%{x?} %{y?}"]          => "<%= x? %> <%= y? %>",
    }
  end
  
  it "should replace %%{key} with %{key} (escaping)" do
    expect_map meth, {
      ["%%{key}"]              => "%{key}",
      ["blah %%{key}"]         => "blah %{key}",
      ["%%{key} blah"]         => "%{key} blah",
      ["blah\n%%{key}\nblah"]  => "blah\n%{key}\nblah",
      ["%%{x} %%{y}"]          => "%{x} %{y}",
      ["%%%{key}"]             => "%%{key}",
    }
  end
  
  it "should replace %%{key?} with %{key?} (escaping)" do
    expect_map meth, {
      ["%%{key?}"]              => "%{key?}",
      ["blah %%{key?}"]         => "blah %{key?}",
      ["%%{key?} blah"]         => "%{key?} blah",
      ["blah\n%%{key?}\nblah"]  => "blah\n%{key?}\nblah",
      ["%%{x?} %%{y?}"]         => "%{x?} %{y?}",
      ["%%%{key?}"]             => "%%{key?}",
    }
  end
   
  it "should replace %<key>s with <%= key %>" do
    expect_map meth, {
      ["%<key>s"]              => "<%= key %>",
      ["blah %<key>s"]         => "blah <%= key %>",
      ["%<key>s blah"]         => "<%= key %> blah",
      ["blah\n%<key>s\nblah"]  => "blah\n<%= key %>\nblah",
      ["%<x>s %<y>s"]          => "<%= x %> <%= y %>",
    }
  end
  
  it "should replace %<key?>s with <%= key? %>" do
    expect_map meth, {
      ["%<key?>s"]              => "<%= key? %>",
      ["blah %<key?>s"]         => "blah <%= key? %>",
      ["%<key?>s blah"]         => "<%= key? %> blah",
      ["blah\n%<key?>s\nblah"]  => "blah\n<%= key? %>\nblah",
      ["%<x?>s %<y?>s"]         => "<%= x? %> <%= y? %>",
    }
  end
  
  it "should replace %%<key>s with %<key>s (escaping)" do
    expect_map meth, {
      ["%%<key>s"]              => "%<key>s",
      ["blah %%<key>s"]         => "blah %<key>s",
      ["%%<key>s blah"]         => "%<key>s blah",
      ["blah\n%%<key>s\nblah"]  => "blah\n%<key>s\nblah",
      ["%%<x>s %%<y>s"]         => "%<x>s %<y>s",
      ["%%%<key>s"]             => "%%<key>s",
    }
  end
  
  it "should replace %%<key?>s with %<key?>s (escaping)" do
    expect_map meth, {
      ["%%<key?>s"]              => "%<key?>s",
      ["blah %%<key?>s"]         => "blah %<key?>s",
      ["%%<key?>s blah"]         => "%<key?>s blah",
      ["blah\n%%<key?>s\nblah"]  => "blah\n%<key?>s\nblah",
      ["%%<x?>s %%<y?>s"]        => "%<x?>s %<y?>s",
      ["%%%<key?>s"]             => "%%<key?>s",
    }
  end
  
  
  it "should not touch % that don't fit the shortcut sytax" do
    expect_map meth, {
      ["50%"]                     => "50%",
      ["50%savings!"]             => "50%savings!",
    }
  end
  
  context "% proceeded by =" do
    it "should do %s substitution when proceeded by an =" do
      expect_map meth, {
        ["X=%s"]          => "X=<%= arg %>",
        ["hey there=%s"]  => "hey there=<%= arg %>",
      }
    end
    
    
    it "should do %{key} substitution when proceeded by an =" do
      expect_map meth, {
        ["X=%{key}"]      => "X=<%= key %>",
        ["hey there=%{key}"]  => "hey there=<%= key %>",
      }
    end
    
    
    it "should do %<key>s substitution when proceeded by an =" do
      expect_map meth, {
        ["X=%<key>s"]          => "X=<%= key %>",
        ["hey there=%<key>s"]  => "hey there=<%= key %>",
      }
    end
  end # % proceeded by =
end
