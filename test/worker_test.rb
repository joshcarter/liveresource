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

  def test_worker_feeds_from_redis
    resource = LiveResource.new("foo")
    redis = Redis.new
    
    resource.on(:upcase) do |param|
      param.upcase
    end

    # NOTE: in normal use, application code would never create 
    # the worker directly, set stuff in Redis, etc.
    redis.hset "foo.actions.1", "method", YAML::dump(:upcase)
    redis.hset "foo.actions.1", "params", YAML::dump(["foobar"])
    redis.lpush "foo.actions", "1"
    redis.lpush "foo.actions", "exit"
    
    worker = LiveResource::Worker.new(resource)
    worker.main

    list, result = redis.brpop "foo.results.1", 0
    redis.del "foo.actions.1"
    result = YAML::load(result)

    assert_equal "FOOBAR", result
    assert_equal nil, Redis.new.info["db0"]
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
    
    # Should have no junk left over in Redis
    assert_equal nil, Redis.new.info["db0"]
  end

  def test_action_stress
    with_worker("foo") do
      resource = LiveResource.new("foo")
      
      100.times do
        resource.action(:upcase, "foobar")
      end
    end
    
    # Should have no junk left over in Redis
    assert_equal nil, Redis.new.info["db0"]
  end
end
