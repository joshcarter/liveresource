require 'rubygems'
require 'rubygems/package_task'
require 'rake/testtask'
require 'yard'

desc "Default Task (test)"
task :default => [:test]

# :test is an alias for the resource and supervisor tests
desc "Resource and supervisor tests"
task :test => ['test:resource', 'test:supervisor']

namespace :test do
  # Just do resource tests
  Rake::TestTask.new :resource do |test|
    test.verbose = false
    test.warning = true
    test.test_files = ['test/*_test.rb'].sort
  end

  # Just do supervisor tests
  Rake::TestTask.new :supervisor do |test|
    test.verbose = false
    test.warning = true
    test.test_files = ['test/supervisor/*_test.rb'].sort
  end

  # Benchmarks (not run as part of higher-level test task)
  Rake::TestTask.new :benchmark do |benchmark|
    benchmark.verbose = false
    benchmark.warning = true
    #  benchmark.options = '--verbose=s'
    benchmark.test_files = ['benchmark/*_benchmark.rb']
  end
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
  spec.version = '2.1.1'
  spec.author = 'Spectra Logic'
	spec.email = 'public@joshcarter.com'
	spec.homepage = 'https://github.com/joshcarter/liveresource'
	spec.description = 'Remote-callable attributes and methods for ' \
    'IPC and cluster use.'

  spec.files = Dir['Rakefile', '{benchmark,lib,test}/**/*', 'BSDL',
                   'COPYING', 'GPL', 'README*']

  spec.add_dependency 'redis'
	spec.add_development_dependency 'mocha'
	spec.add_development_dependency 'yard'
end

gem = Gem::PackageTask.new(gem_spec) do |pkg|
  pkg.need_tar = false
  pkg.need_zip = false
end
