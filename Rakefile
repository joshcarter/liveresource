require 'rubygems'
require 'rubygems/package_task'
require 'rake/testtask'
require 'yard'

desc "Default Task"
task :default => [:test]

# Test everything
Rake::TestTask.new :test do |test|
  test.verbose = false
  test.warning = true
  test.test_files = ['test/*_test.rb', 'test/supervisor/*_test.rb'].sort
end

# Just do resource tests
Rake::TestTask.new :resource_test do |test|
  test.verbose = false
  test.warning = true
  test.test_files = ['test/*_test.rb'].sort
end

# Just do supervisor tests
Rake::TestTask.new :supervisor_test do |test|
  test.verbose = false
  test.test_files = ['test/supervisor/*_test.rb'].sort
end

Rake::TestTask.new :benchmark do |benchmark|
  benchmark.verbose = false
	#  benchmark.options = '--verbose=s'
  benchmark.test_files = ['benchmark/*_benchmark.rb']
end

YARD::Rake::YardocTask.new do |t|
  t.files = ['lib/**/*.rb']
end

task :clean do
  FileUtils.rm_rf 'pkg'
end

task :ctags do
  system 'ctags -R .'
end

gem_spec = Gem::Specification.new do |spec|
  spec.name = 'liveresource'
  spec.summary = 'Live Resource'
  spec.version = '2.1.0'
  spec.author = 'Spectra Logic'
	spec.email = 'public@joshcarter.com'
	spec.homepage = 'https://github.com/joshcarter/liveresource'
	spec.description = 'Remote-callable attributes and methods for ' \
    'IPC and cluster use.'

  spec.files = Dir['Rakefile', '{benchmark,lib,old,test}/**/*', 'BSDL',
                   'COPYING', 'GPL', 'README*']

  spec.add_dependency 'redis'
	spec.add_development_dependency 'yard'
end

gem = Gem::PackageTask.new(gem_spec) do |pkg|
  pkg.need_tar = false
  pkg.need_zip = false
end
