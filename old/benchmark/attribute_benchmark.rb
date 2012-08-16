require File.join(File.dirname(__FILE__), 'benchmark_helper')

class Resource
  include LiveResource::Attribute
  
  remote_accessor :attribute
  
  def initialize
    self.namespace = 'test'
  end
end

class AttributeTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end

  def run_with_threads(n_threads, n_total, &block)
    threads = []

    n_threads.times do
      threads << Thread.new do
        (n_total / n_threads).times { block.call }
      end
    end

    threads.each { |t| t.join }
  end

  def test_attribute_performance
    resource = Resource.new
    n = 10000
    
    puts "Attribute get/set performance".title

    Benchmark.bm do |x|
      x.report("attr read (n=#{n})".pad) do
        n.times { resource.attribute }
      end

      x.report("attr write (n=#{n})".pad) do
        n.times { resource.attribute = 1 }
      end      
      
      [1, 5, 10].each do |threads|
        x.report("attr read (n=#{n}, #{threads} threads):".pad) do
          run_with_threads(threads, n) { resource.attribute }
        end
      
        x.report("attr write (n=#{n}, #{threads} threads):".pad) do
          run_with_threads(threads, n) { resource.attribute = 1 }
        end
      end
    end

    assert true
  end
end