require 'live_resource'
require 'test/unit'
require 'thread'
require 'yaml'

Thread.abort_on_exception = true

class WorkerTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
    @trace = false
  end
  
  def trace(s)
    puts("- #{s}") if @trace
  end

  def DISABLED_test_worker_feeds_from_redis
    resource = LiveResource.new("foo")
    redis = Redis.new
    
    resource.on(:upcase) do |param|
      param.upcase
    end

    # NOTE: in normal use, application code would never create 
    # the worker directly, set stuff in Redis, etc.
    redis.hset "foo.actions.1", "method", YAML::dump(:upcase)
    redis.hset "foo.actions.1", "params", YAML::dump("foobar")
    redis.lpush "foo.actions", "1"
    redis.lpush "foo.actions", "exit"
    
    worker = LiveResource::Worker.new(resource)
    worker.main

    # It appears that hset followed immediately by an hget may not 
    # return the new value. Loop here for just a bit.
    10.times do
      break if redis.hkeys('foo.actions.1').include?('result')
      sleep 0.1
    end

    assert_equal "FOOBAR", YAML::load(redis.hget("foo.actions.1", "result"))
  end
  
  # TODO: test with 0, 1, 2 parameter jobs
  def test_action_api
    r1 = LiveResource.new("foo")
    r2 = LiveResource.new("foo")
    
    r1.on(:upcase) do |param|
      param.upcase
    end

    r1.start_worker
    
    assert_equal "FOOBAR", r2.action(:upcase, "foobar")
    
    r2.stop_worker
  end
end