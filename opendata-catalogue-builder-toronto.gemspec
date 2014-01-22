# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'opendata/catalogue/builder/toronto/version'

Gem::Specification.new do |spec|
  spec.name          = "opendata-catalogue-builder-toronto"
  spec.version       = Opendata::Catalogue::Builder::Toronto::VERSION
  spec.authors       = ["Raymond Kao"]
  spec.email         = ["ray@peopleandcode.com"]
  spec.description   = %q{TODO: Write a gem description}
  spec.summary       = %q{TODO: Write a gem summary}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "nokogiri"
  spec.add_dependency "mongo"
  spec.add_dependency "ruby-progressbar"
  

end
