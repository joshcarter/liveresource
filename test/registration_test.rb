require_relative 'test_helper'

class RegistrationTest < Test::Unit::TestCase
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

    # There shouldn't be anything in Redis about this resource yet.
    assert !r.registered?
    assert_equal 0, r.num_instances

    # Register the resource and wait for a message.
    class_resource = LiveResource::register Foo

    # Should get a created message for this resource.
    msg = q.pop
    assert_equal "class.foo.created", msg

    # The resource is registered but there are no instances
    assert r.registered?
    assert_equal 0, r.num_instances

    # Start the resource
    class_resource.start

    # Should get a started message for this resource.
    msg = q.pop
    assert_equal "class.foo.started", msg

    # Class resources don't have instance parameters.
    assert_equal nil, r.instance_params

    # Stop the resource and wait for a stopped message.
    LiveResource::stop
    msg = q.pop
    assert_equal "class.foo.stopped", msg

    # Make sure everything is cleaned up.
    assert_equal 0, r.num_instances
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

    LiveResource::register(Foo).start
    LiveResource::find(:foo).new("foo")

    # Ensure we get all created/started events (note we don't know which order we'll get them
    # in).
    events = ["class.foo.created", "class.foo.started", "foo.foo.created", "foo.foo.started"]
    until events.empty?
      msg = q.pop
      assert_not_nil events.delete(msg)
    end

    # There should be one instance of the resource.
    assert_equal 1, r.num_instances

    # Check the instance params are correct
    assert_equal ["foo"], r.instance_params

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
  end
end