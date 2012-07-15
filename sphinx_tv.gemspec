# -*- encoding: utf-8 -*-
require File.expand_path('../lib/sphinx_tv/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["David Monagle"]
  gem.email         = ["david.monagle@intrica.com.au"]
  gem.date        = '2012-07-15'
  gem.summary     = "SphinxTV is an installer/configurator for MythTV (and others) for OSX"
  gem.description = "SphinxTV is an installer/configurator for MythTV (and others) for OSX"
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "sphinx_tv"
  gem.require_paths = ["lib"]
  gem.version       = SphinxTv::VERSION
  gem.homepage    =
    'http://sphinxtv.intrica.com.au'
  gem.add_dependency 'colorize'
  gem.add_dependency 'highline'
  gem.add_dependency 'nokogiri'
end
