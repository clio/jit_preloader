# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jit_preloader/version'

Gem::Specification.new do |spec|
  spec.name          = "jit_preloader"
  spec.version       = JitPreloader::VERSION
  spec.authors       = ["Kyle d'Oliveira"]
  spec.email         = ["kyle.doliveira@clio.com"]
  spec.summary       = %q{Tool to understand N+1 queries and to remove them}
  spec.description   = %q{The JitPreloader has the ability to send notifications when N+1 queries occur to help guage how problematic they are for your code base and a way to remove all of the commons explicitly or automatically}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "> 4.2"
  spec.add_dependency "activesupport"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "db-query-matchers"
end
