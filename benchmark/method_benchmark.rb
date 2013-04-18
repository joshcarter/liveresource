require_relative 'benchmark_helper'

class Server
  include LiveResource::Resource

  resource_class :server
  resource_name :object_id

  def test_method
    42
  end
end

class MethodTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
    LiveResource::register Server.new
  end

  def teardown
    LiveResource::stop
  end

  def test_sync_method_performance
    n = 1000

    puts "Synchronous method call performance".title

    [1, 5, 10].each do |threads|
      b = Benchmark.measure do
        run_sync(n, threads)
      end

      output = "n=#{n}, #{threads} threads: #{b.to_s.strip} " +
        sprintf("%.0f m/sec", n / b.total)
      puts output.pad
    end

    assert true
  end

  def test_async_method_performance
    n = 1000

    puts "Asynchronous method call performance".title

    [1, 10, 100].each do |batch_size|
      b = Benchmark.measure do
        run_async(n, batch_size)
      end

      output = "n=#{n}, batches of #{batch_size}: #{b.to_s.strip} " +
        sprintf("%.0f m/sec", n / b.total)
      puts output.pad
    end

    assert true
  end

  def run_sync(n, n_threads)
    threads = []

    n_threads.times do
      threads << Thread.new do
        server = LiveResource::any(:server)

        (n / n_threads).times { server.test_method }
      end
    end

    threads.each { |t| t.join }
  end

  def run_async(n, batch_size)
    server = LiveResource::any(:server)
    futures = Queue.new

    # Calls
    send_thread = Thread.new do
      n.times do
        Thread.pass while (futures.length >= batch_size)

        futures << server.test_method?
      end
    end

    # Results
    n.times do
      Thread.pass while futures.empty?

      futures.pop.value
    end

    send_thread.join
  end
end
