require 'set'
require 'thread'
require_relative 'test_helper'

class ForwardContinueTest < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    resource_name :object_id
    resource_class :class_1

    def method1(param1, param2)
      c2 = LiveResource::any(:class_2)
      c3 = LiveResource::any(:class_3)
      param3 = "baz"

      forward(c2, :method2, param1, param2, param3).continue(c3, :method3)
    end
  end

  class Class2
    include LiveResource::Resource

    resource_name :object_id
    resource_class :class_2

    def method2(param1, param2, param3)
      [param1, param2, param3].join('-')
    end
  end

  class Class3
    include LiveResource::Resource

    resource_name :object_id
    resource_class :class_3

    def method3(param1)
      param1.upcase
    end
  end

  def setup
    flush_redis

    @class1 = Class1.new
    @class2 = Class2.new
    @class3 = Class3.new
  end

  def teardown
    LiveResource::stop
  end

  def test_instances_have_methods
    i = LiveResource::all(:class_1).first

    assert i.respond_to?(:method1), "instance does not respond to method1"
  end

  def test_instances_have_async_methods
    i = LiveResource::all(:class_1).first

    assert i.respond_to?(:method1!), "instance does not respond to method1!"
    assert i.respond_to?(:method1?), "instance does not respond to method1?"
  end

  def test_instance_does_not_respond_to_invalid_methods
    i = LiveResource::all(:class_1).first

    assert !i.respond_to?(:method2), "instance should not respond to method2"
    assert !i.respond_to?(:method2!), "instance should not respond to method2!"
    assert !i.respond_to?(:method2?), "instance should not respond to method2?"
  end

  def test_message_path
    starting_keys = Set.new(redis_keys)

    # The methods_in_progress list is cleaned up in the resource instance
    # thread after the result has been sent.  Need to wait for "method_done"
    # to be called before checking the Redis keys.  This should only be
    # necessary for the 3rd instance since the other two should have been
    # cleaned up by the time this runs.
    method_done_queue = Queue.new
    class << @class3.redis
      def method_done_queue=(queue)
        @method_done_queue = queue
      end
      alias original_method_done method_done
      def method_done(token)
        original_method_done(token)
        @method_done_queue << token
      end
    end
    @class3.redis.method_done_queue = method_done_queue

    # LiveResource::RedisClient::logger.level = Logger::DEBUG
    assert_equal "FOO-BAR-BAZ", LiveResource::any(:class_1).method1("foo", "bar")

    method_done_queue.pop

    ending_keys = Set.new(redis_keys)

    # Should have no junk left over in Redis
    assert_equal starting_keys, ending_keys
  end
end
