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
    Redis.new.flushall

    Class1.new
    Class2.new
    Class3.new
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
    starting_keys = Redis.new.dbsize

    # LiveResource::RedisClient::logger.level = Logger::DEBUG
    assert_equal "FOO-BAR-BAZ", LiveResource::any(:class_1).method1("foo", "bar")

    # Should have no junk left over in Redis
    assert_equal starting_keys, Redis.new.dbsize
  end
end
