require 'set'

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
    flush_redis

    LiveResource::RedisClient.logger.level = Logger::INFO

    # Redis client for the instance resource.
    r = LiveResource::RedisClient.new(:foo, :foo)

    # Event queue
    @q = Queue.new
    
    # Start a new thread and subscribe to the instance event channel
    @t = Thread.new do
      LiveResource::RedisClient.redis.subscribe(r.instance_channel) do |on|
        on.subscribe do |channel, msg|
          @q.push "subscribed"
        end
        on.message do |channel, msg| 
          @q.push msg
        end
      end
    end


  end

  def teardown
    @t.kill
    @t.join
  end

  def test_new_class_instance
    # Wait for subscribe event.
    msg = @q.pop
    assert_equal "subscribed", msg

    # Redis client for the class resource.
    r = LiveResource::RedisClient.new(:class, :foo)

    # There shouldn't be anything in Redis about this resource yet.
    assert !r.registered?
    assert_equal 0, r.num_instances

    # Register the resource and wait for a message.
    class_resource = LiveResource::register Foo

    # Should get a created message for this resource.
    msg = @q.pop
    assert_equal "class.foo.created", msg

    # The resource is registered but there are no instances
    assert r.registered?
    assert_equal 0, r.num_instances

    # Register the resource again to prove that an event should not be
    # published if nothing changed, which will be tested when the
    # 'class.foo.started' event is tested.
    LiveResource::register Foo

    # Methods and attributes were registered
    assert_equal r.registered_methods.to_set, Foo.remote_methods.to_set
    assert_equal r.registered_attributes.to_set, Foo.remote_attributes.to_set

    # Start the resource
    class_resource.start

    # Should get a started message for this resource.
    msg = @q.pop
    assert_equal "class.foo.started", msg

    # Class resources don't have instance parameters.
    assert_equal nil, r.instance_params

    # Update the class definition and re-register it.
    Foo.define_singleton_method :new_class_method do end
    assert_equal [:new, :ruby_new, :new_class_method].to_set, Foo.remote_methods.to_set
    LiveResource::register Foo
    assert_equal [:new, :ruby_new, :new_class_method].to_set, r.registered_methods.to_set
     
    # Should get an updated message for this resource.
    msg = @q.pop
    assert_equal "class.foo.updated", msg

    # Stop the resource and wait for a stopped message.
    LiveResource::stop
    msg = @q.pop
    assert_equal "class.foo.stopped", msg

    # Make sure everything is cleaned up.
    assert_equal 0, r.num_instances
  end

  def test_new_instance
    # Redis client for the instance resource.
    r = LiveResource::RedisClient.new(:foo, :foo)
    # Redis client for the second instance resource.
    r2 = LiveResource::RedisClient.new(:foo, :bar)

    # Wait for subscribe event.
    msg = @q.pop
    assert_equal "subscribed", msg

    LiveResource::register(Foo).start
    LiveResource::find(:foo).new("foo")

    # Ensure we get all created/started events (note we don't know which order we'll get them
    # in).
    events = ["class.foo.created", "class.foo.started", "foo.foo.created", "foo.foo.started"]
    until events.empty?
      msg = @q.pop
      assert_not_nil events.delete(msg)
    end

    # Add another method/attribute and register another instance.
    # Verify the new attribute/method is available for both the already
    # existing instance and the new one.
    Foo.send(:define_method, :new_instance_method) {}
    Foo.remote_reader :new_reader
    assert_equal [:delete], r2.registered_methods
    assert_equal [:name, :name=].to_set, r2.registered_attributes.to_set
    LiveResource::find(:foo).new('bar')
    assert_equal [:delete, :new_instance_method].to_set, r.registered_methods.to_set
    assert_equal [:delete, :new_instance_method].to_set, r2.registered_methods.to_set
    assert_equal [:name, :name=, :new_reader].to_set, r.registered_attributes.to_set
    assert_equal [:name, :name=, :new_reader].to_set, r2.registered_attributes.to_set

    msg = @q.pop
    assert_equal "foo.bar.created", msg

    msg = @q.pop
    assert_equal "foo.bar.started", msg

    # There should be two instances of the resource.
    assert_equal 1, r.num_instances
    assert_equal 1, r2.num_instances

    # Check the instance params are correct
    assert_equal ["foo"], r.instance_params

    LiveResource::stop

    # Ensure we get both stopped events (note we don't know which order we'll get them
    # in).
    events = ["class.foo.stopped", "foo.foo.stopped", "foo.bar.stopped"]
    until events.empty?
      msg = @q.pop
      assert_not_nil events.delete(msg)
    end

    # Make sure everything is cleaned up (note that the instance init params stay
    # in Redis).
    assert_equal 0, r.num_instances
    assert_equal ["foo"], r.instance_params
  end

  def test_delete_instance
    # Redis client for the instance resource.
    r = LiveResource::RedisClient.new(:foo, :foo)

    # Wait for subscribe event.
    msg = @q.pop
    assert_equal "subscribed", msg

    LiveResource::register(Foo).start
    LiveResource::find(:foo).new("foo")

    # Ensure we get all created/started events (note we don't know which order we'll get them
    # in).
    events = ["class.foo.created", "class.foo.started", "foo.foo.created", "foo.foo.started"]
    until events.empty?
      msg = @q.pop
      assert_not_nil events.delete(msg)
    end

    # Should be one instance of foo
    assert_equal 1, r.num_instances

    # Create another foo instance
    LiveResource::find(:foo).new("foo")

    # Wait for new instance to start
    msg = @q.pop
    assert_equal "foo.foo.started", msg

    # Now there are two instances
    assert_equal 2, r.num_instances

    # Get a proxy to to foo and delete it.
    f = LiveResource::find(:foo, "foo")
    f.delete

    # Expect 2 stopped events
    2.times do
      msg = @q.pop
      assert_equal "foo.foo.stopped", msg
    end

    # Should get at least one deleted event
    msg = @q.pop
    assert_equal "foo.foo.deleted", msg

    # Depending on timing, we might get another deleted event. Wait up to 3 seconds
    # for it
    3.times do
      unless @q.empty?
        msg = @q.pop
        assert_equal "foo.foo.deleted", msg
        break
      end
      sleep 1
    end

    # There are no instances of foo anymore
    assert_equal 0, r.num_instances
    assert_equal false, r.exists(r.instance_params_key)
    assert_equal false, r.exists(r.remote_methods_key)
    assert_equal false, r.exists(r.remote_attributes_key)
    assert_equal false, r.exists("foo.foo.attributes.name")

    # Stop and waith for class stopped event
    LiveResource::stop

    msg = @q.pop
    assert_equal "class.foo.stopped", msg
  end
end
