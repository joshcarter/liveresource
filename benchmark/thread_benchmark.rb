require File.join(File.dirname(__FILE__), 'benchmark_helper')

class Supervisor
  CONCURRENT_WORKERS = 10
  
  def main(total_jobs)
    redis = Redis.new
    mutex = Mutex.new
    workers = 0
    
    # Very roughly simulate having a pool of worker threads.
    loop do
      return if (redis.llen("results") == total_jobs)

      Thread.pass while (mutex.synchronize { workers >= CONCURRENT_WORKERS })
      
      Thread.new do
        mutex.synchronize { workers += 1 }
        # puts "Doing work (#{workers} workers)"
        Worker.new.work(1)
        mutex.synchronize { workers -= 1 }
      end
    end
  end
end

class Worker
  def work(loops)
    redis = Redis.new
    
    loops.times do
      job = redis.brpop "work", 0      
      redis.lpush "results", job
    end
  end
end

class ThreadTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end
  
  def run_single_thread(jobs)
    redis = Redis.new
    
    jobs.times do
      redis.lpush "work", "foo"
    end
    
    thread = Thread.new do
      Worker.new.work(jobs)
    end
    
    thread.join
  end
  
  def run_thread_spawn_on_demand(jobs)
    redis = Redis.new
    
    jobs.times do
      redis.lpush "work", "foo"
    end

    Supervisor.new.main(jobs)
  end
  
  def test_thread_performance
    n = 10000
   
    # Test which is faster: run one thread sitting on Redis vs. many 
    # threads (one per job) dogpiling on Redis. That is, is the cost
    # of spawning one thread per job more expensive than the IO to
    # Redis? (On my machine, thread pool is nearly 4x faster. -jdc)
    Benchmark.bm do |x|
      x.report("single thread:") { run_single_thread(n) }
      x.report("thread pool:  ") { run_thread_spawn_on_demand(n) }
    end
    
    assert true
  end
end