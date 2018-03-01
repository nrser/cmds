# frozen_string_literal: true
# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cmds/version'

Gem::Specification.new do |spec|
  spec.name          = "cmds"
  spec.version       = Cmds::VERSION
  spec.authors       = ["nrser"]
  spec.email         = ["neil@ztkae.com"]
  spec.summary       = %q{helps read, write and remember commands.}
  # spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = "https://github.com/nrser/cmds"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  
  
  # Dependencies
  # ============================================================================
  
  # Runtime Dependencies
  # ----------------------------------------------------------------------------
  
  # Mu guns
  spec.add_dependency             "nrser",          ">= 0.2.0.pre.3"
  
  # ERB replacement with more features
  # 
  # Allows custom auto-escaping, which allows us to shell quote when rendering
  # values into command templates.
  # 
  spec.add_dependency             'erubis',         '~> 2.7'
  
  
  # Development Dependencies
  # ----------------------------------------------------------------------------
  
  # You've probably heard of Bundler. I like Bundler.
  spec.add_development_dependency "bundler",        "~> 1.5"
  
  # And you've probably hear of Rake. I don't like Rake.
  spec.add_development_dependency "rake"
  
  # For coloring debug logs. Want to get rid of it when I finally get around to
  # fixing up logging on config in NRSER and can just use that.
  spec.add_development_dependency "pastel"
  
  # Testing with `rspec`
  spec.add_development_dependency "rspec",          '~> 3.7'
  
  # Doc site generation with `yard`
  spec.add_development_dependency "yard",           '~> 0.9.12'
  
  # These, along with `//.yardopts` config, are *supposed to* result in
  # rendering markdown files and doc comments using
  # GitHub-Flavored Markdown (GFM), though I'm not sure if it's totally working
  spec.add_development_dependency "redcarpet",      '~> 3.4'
  spec.add_development_dependency "github-markup",  '~> 1.6'
  
  # Nicer REPL experience
  spec.add_development_dependency "pry",            '~> 0.10.4'
  
end
