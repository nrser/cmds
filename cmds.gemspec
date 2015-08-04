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
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'nrser', '~> 0.0.12'
  spec.add_dependency 'erubis', '~> 2.7.0'

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pastel"
end
