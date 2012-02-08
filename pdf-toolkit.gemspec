require 'rubygems' rescue nil

$:.unshift File.expand_path('../lib', __FILE__)
require "pdf/toolkit"

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'pdf-toolkit'
  s.summary = 'A wrapper around pdftk to allow PDF metadata manipulation'
  s.description = 'PDF::Toolkit provides a simple interface for querying and unpdation PDF metadata like the document Author and Title.'
  s.version = PDF::Toolkit::VERSION

  s.authors = ['Tim Pope', 'Bernard Lambeau']
  s.email   = ['ruby@tp0pe.inf0'.gsub(/0/,'o'), "blambeau@gmail.com"]

  s.rubyforge_project = 'pdf-toolkit'
  s.homepage = "http://pdf-toolkit.rubyforge.org"

  s.has_rdoc = true
  s.require_path = 'lib'

  s.files = [ "Rakefile", "README.md", "LICENCE.md", "pdf-toolkit.gemspec" ]
  s.files = s.files + Dir.glob( "lib/**/*.rb" )
  s.files = s.files + Dir.glob( "test/**/*" )
end

