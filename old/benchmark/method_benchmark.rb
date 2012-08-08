require File.join(File.dirname(__FILE__), 'benchmark_helper')

class Server
  include LiveResource::MethodProvider
  
  remote_method :test_method
  
  def initialize
    self.namespace = 'test'
  end
  
  def test_method
    42
  end
end

class Client
  include LiveResource::MethodSender
  
  def initialize
    self.namespace = 'test'
  end
  
  def run_sync(n, n_threads)
    threads = []

    n_threads.times do
      threads << Thread.new do
        (n / n_threads).times { remote_send(:test_method) }
      end
    end

    threads.each { |t| t.join }
  end
  
  def run_async(n, batch_size)
    tokens = Queue.new
    
    # Calls
    send_thread = Thread.new do
      n.times do
        Thread.pass while (tokens.length >= batch_size)
        
        tokens.push remote_send_async(:test_method)
      end
    end
    
    # Results
    n.times do
      Thread.pass while tokens.empty?
      
      wait_for_done(tokens.pop)
    end
    
    send_thread.join
  end
end

class MethodTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end

  def test_sync_method_performance
    server = Server.new
    client = Client.new
    n = 1000
    
    server.start_method_dispatcher
    
    puts "Synchronous method call performance".title

    Benchmark.bm do |x|
      [1, 5, 10].each do |threads|
        x.report("sync method call (n=#{n}, #{threads} threads):".pad) do
          client.run_sync(n, threads)
        end
      end
    end

    server.stop_method_dispatcher
    assert true
  end
  
  def test_async_method_performance
    server = Server.new
    client = Client.new
    n = 1000
    
    server.start_method_dispatcher
    
    puts "Asynchronous method call performance".title

    Benchmark.bm do |x|
      [1, 5, 10].each do |batch_size|
        x.report("async method call (n=#{n}, batches of #{batch_size}):".pad) do
          client.run_async(n, batch_size)
        end
      end
    end

    server.stop_method_dispatcher
    assert true
  end
end