
require 'rubygems'

require 'rake'
require 'rake/clean'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/testtask'

#require 'rake/rdoctask'
require 'hanna/rdoctask'

require 'lib/rufus/treechecker' # Rufus::TreeChecker::VERSION

#
# GEM SPEC

spec = Gem::Specification.new do |s|

  s.name = "rufus-treechecker"
  s.version = Rufus::TreeChecker::VERSION
  s.authors = [ "John Mettraux" ]
  s.email = "john at openwfe dot org"
  s.homepage = "http://rufus.rubyforge.org/rufus-treechecker"
  s.platform = Gem::Platform::RUBY
  s.summary = "checking ruby code before eval()"
  #s.license = "MIT"
  s.rubyforge_project = "rufus"

  s.require_path = "lib"
  #s.autorequire = "rufus-whatever"
  s.test_file = "test/test.rb"
  s.has_rdoc = false
  s.extra_rdoc_files = [ 'README.txt' ]

  [ 'ruby_parser' ].each do |d|
    s.requirements << d
    s.add_dependency d
  end

  files = FileList[ "{bin,docs,lib,test}/**/*" ]
  files.exclude "html"
  #files.exclude "extras"
  s.files = files.to_a
end

#
# tasks

CLEAN.include('pkg', 'html')

task :default => [ :clean, :repackage ]


#
# TESTING

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test.rb']
  t.verbose = true
end

#
# PACKAGING

Rake::GemPackageTask.new(spec) do |pkg|
  #pkg.need_tar = true
end

Rake::PackageTask.new("rufus-treechecker", Rufus::TreeChecker::VERSION) do |pkg|
  pkg.need_zip = true
  pkg.package_files = FileList[
    'Rakefile',
    '*.txt',
    'lib/**/*',
    'test/**/*'
  ].to_a
  #pkg.package_files.delete("MISC.txt")
  class << pkg
    def package_name
      "#{@name}-#{@version}-src"
    end
  end
end

#
# DOCUMENTATION

Rake::RDocTask.new do |rd|

  rd.main = 'README.txt'
  rd.rdoc_dir = 'html/rufus-treechecker'
  rd.rdoc_files.include(
    'README.txt',
    'CHANGELOG.txt',
    'LICENSE.txt',
    'CREDITS.txt',
    'lib/**/*.rb')
  #rd.rdoc_files.exclude('lib/tokyotyrant.rb')
  rd.title = 'rufus-treechecker rdoc'
  rd.options << '-N' # line numbers
  rd.options << '-S' # inline source
end

task :rrdoc => :rdoc do
  FileUtils.cp('doc/rdoc-style.css', 'html/rufus-treechecker/')
end


#
# WEBSITE

task :upload_website => [ :clean, :rrdoc ] do

  account = 'jmettraux@rubyforge.org'
  webdir = '/var/www/gforge-projects/rufus'

  sh "rsync -azv -e ssh html/rufus-treechecker #{account}:#{webdir}/"
end

