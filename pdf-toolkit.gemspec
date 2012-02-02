require File.expand_path("../lib/pdf/toolkit", __FILE__)
require 'rubygems' rescue nil

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'pdf-toolkit'
  s.summary = 'A wrapper around pdftk to allow PDF metadata manipulation'
  s.description = 'PDF::Toolkit provides a simple interface for querying and unpdation PDF metadata like the document Author and Title.'
  s.version = PDF::Toolkit::VERSION

  s.author = 'Tim Pope'
  s.email = 'ruby@tp0pe.inf0'.gsub(/0/,'o')
  s.rubyforge_project = 'pdf-toolkit'
  s.homepage = "http://pdf-toolkit.rubyforge.org"

  s.has_rdoc = true
  s.require_path = 'lib'

  s.add_dependency('activesupport', '>= 2.3.0')

  s.files = [ "Rakefile", "README", "pdf-toolkit.gemspec" ]
  s.files = s.files + Dir.glob( "lib/**/*.rb" )
  s.files = s.files + Dir.glob( "test/**/*" ).reject { |item| item.include?( "\.svn" ) }
end

