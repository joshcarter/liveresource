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
  
  def with_worker(name)
    resource = LiveResource.new(name)
    
    resource.on(:meaning) do 
      42
    end

    resource.on(:upcase) do |str|
      str.upcase
    end

    resource.on(:add) do |a, b|
      a + b
    end

    resource.on(:reverse) do |arr|
      arr.reverse
    end

    begin
      resource.start_worker
      yield
    ensure
      resource.stop_worker
    end
  end

  def test_action_api
    with_worker("foo") do
      resource = LiveResource.new("foo")

      # Zero parameters
      assert_equal 42, resource.action(:meaning)

      # One parameter (simple)
      assert_equal "FOOBAR", resource.action(:upcase, "foobar")

      # One parameter (complex)
      assert_equal [3, 2, 1], resource.action(:reverse, [1, 2, 3])

      # Two parameters
      assert_equal 3, resource.action(:add, 1, 2)
    end
  end
end
