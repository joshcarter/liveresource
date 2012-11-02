require_relative 'test_helper'

class InstanceEventsTest < Test::Unit::TestCase
  class Foo
    include LiveResource::Resource

    resource_class :foo
    resource_name :name

    remote_accessor :name

    def initialize(name)
      self.name = name
    end
  end

  def setup
    Redis.new.flushall

    LiveResource::RedisClient.logger.level = Logger::INFO
  end

  def teardown
  end

  def test_new_class_instance
    q = Queue.new

    # Redis client for the class resource.
    r = LiveResource::RedisClient.new(:class, :foo)

    # Start a new thread and subscribe to the instance event channel
    Thread.new do
      Redis.new.subscribe(r.instance_channel) do |on|
        on.subscribe do |channel, msg|
          q.push "subscribed"
        end
        on.message do |channel, msg| 
          q.push msg
        end
      end
    end

    # Wait for subscribe event.
    msg = q.pop
    assert_equal "subscribed", msg

    # Register the resource and wait for a message.
    LiveResource::register Foo
    msg = q.pop

    # Should get a started message for this resource.
    assert_equal "class.foo.started", msg

    # There should be one instance of the class resource.
    assert_equal 1, r.num_instances

    # Class resources don't have instance parameters.
    assert_equal nil, r.instance_params

    # There should only be one local instance, and it should
    # be this process.
    assert_equal 1, r.local_instance_pids.count
    assert_equal true, r.pid_has_instance?(Process.pid)

    # Stop the resource and wait for a stopped message.
    LiveResource::stop
    msg = q.pop

    assert_equal "class.foo.stopped", msg

    # Make sure everything is cleaned up.
    assert_equal 0, r.num_instances
    assert_equal 0, r.local_instance_pids.count
    assert_equal false, r.pid_has_instance?(Process.pid)
  end

  def test_new_instance
    q = Queue.new

    # Redis client for the instance resource.
    r = LiveResource::RedisClient.new(:foo, :foo)

    # Start a new thread and subscribe to the instance event channel
    Thread.new do
      Redis.new.subscribe(r.instance_channel) do |on|
        on.subscribe do |channel, msg|
          q.push "subscribed"
        end
        on.message do |channel, msg| 
          q.push msg
        end
      end
    end

    # Wait for subscribe event.
    msg = q.pop
    assert_equal "subscribed", msg

    LiveResource::register Foo
    LiveResource::find(:foo).new("foo")

    # Ensure we get both started events (note we don't know which order we'll get them
    # in).
    events = ["class.foo.started", "foo.foo.started"]
    until events.empty?
      msg = q.pop
      assert_not_nil events.delete(msg)
    end

    # There should be one instance of the resource.
    assert_equal 1, r.num_instances

    # Check the instance params are correct
    assert_equal ["foo"], r.instance_params

    # There should only be one local instance, and it should
    # be this process.
    assert_equal 1, r.local_instance_pids.count
    assert_equal true, r.pid_has_instance?(Process.pid)

    LiveResource::stop

    # Ensure we get both stopped events (note we don't know which order we'll get them
    # in).
    events = ["class.foo.stopped", "foo.foo.stopped"]
    until events.empty?
      msg = q.pop
      assert_not_nil events.delete(msg)
    end

    # Make sure everything is cleaned up (note that the instance init params stay
    # in Redis).
    assert_equal 0, r.num_instances
    assert_equal ["foo"], r.instance_params
    assert_equal 0, r.local_instance_pids.count
    assert_equal false, r.pid_has_instance?(Process.pid)
  end
end
