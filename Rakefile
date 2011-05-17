require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'

desc "Default Task"
task :default => [:test]

Rake::TestTask.new :test do |test|
  test.verbose = false
  test.test_files = ['test/*_test.rb']
end

Rake::TestTask.new :benchmark do |benchmark|
  benchmark.verbose = false
  benchmark.options = '--verbose=s'
  benchmark.test_files = ['benchmark/*_benchmark.rb']
end

gem_spec = Gem::Specification.new do |spec|
  spec.name = 'liveresource'
  spec.version = '1.1.0'
  spec.summary = 'Live Resource'
  spec.author = 'Josh Carter <public@joshcarter.com>'
  spec.has_rdoc = false
  candidates = Dir.glob("{lib}/**/*")
  spec.files = candidates.delete_if {|c| c.match(/\.swp|\.svn|html|pkg/)}
end

gem = Rake::GemPackageTask.new(gem_spec) do |pkg|
  pkg.need_tar = false
  pkg.need_zip = false
end
