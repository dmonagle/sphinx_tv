Gem::Specification.new do |s|
  s.name        = 'sphinx_tv'
  s.version     = '0.9.0'
  s.date        = '2012-07-15'
  s.summary     = "SphinxTV is an installer/configurator for MythTV (and others) for OSX"
  s.description = "SphinxTV is an installer/configurator for MythTV (and others) for OSX"
  s.authors     = ["David Monagle"]
  s.email       = 'david.monagle@intrica.com.au'
  s.files       = Dir["{lib,resources}/**/*"]
  s.add_dependency 'colorize'
  s.add_dependency 'highline'
  s.add_dependency 'nokogiri'
  s.homepage    =
    'http://sphinxtv.intrica.com.au'
  s.executables << 'sphinx_tv'
end