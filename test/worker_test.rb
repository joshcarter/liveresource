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

  def test_worker_exits_on_exit_token
    resource = LiveResource.new("foo")
    redis = Redis.new
    
    resource.on(:upcase) do |param|
      param.upcase
    end

    # NOTE: in normal use, application code would never create 
    # the worker directly, set stuff in Redis, etc.
    redis.hset "foo.actions.1234", "method", YAML::dump(:upcase)
    redis.hset "foo.actions.1234", "params", YAML::dump("foobar")
    redis.lpush "foo.actions", "1234"
    redis.lpush "foo.actions", "exit"
    
    worker = LiveResource::Worker.new(resource)
    worker.main

    # It appears that hset followed immediately by an hget may not 
    # return the new value. Loop here for just a bit.
    10.times do
      break if redis.hkeys('foo.actions.1234').include?('result')
      sleep 0.1
    end

    assert_equal "FOOBAR", YAML::load(redis.hget("foo.actions.1234", "result"))
  end
end