require_relative 'test_helper'

class ForwardContinueTest < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    attr_reader :name
    resource_name :name
    resource_class :class_1

    def initialize(name)
      @name = name
    end

    def method1(param1, param2)
      param1 + param2
    end

    # def method1(param1, param2)
    #   to1 = LiveResource::any(:class_2)
    #   to2 = LiveResource::any(:class_3)
    #   param3 = "baz"
    #
    #   forward(to1, param1, param2, param3).continue(to2)
    # end
  end

  class Class2
    include LiveResource::Resource

    resource_name :object_id
    resource_class :class_2

    def method2(param1, param2, param3)
      param1
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

    LiveResource::RedisClient.logger.level = Logger::INFO

    # Class resources
    LiveResource::register Class1
    LiveResource::register Class2
    LiveResource::register Class3

    # Instance resources
    obj1 = LiveResource::register Class1.new("bob")
    LiveResource::register Class1.new("sue")
    LiveResource::register Class1.new("fred")
    LiveResource::register Class2.new
    LiveResource::register Class3.new
  end

  def teardown
    LiveResource::stop
  end

  def test_find_instance
    assert_equal 3, LiveResource::all(:class_1).length

    assert_not_nil LiveResource.find(:class_1, :fred)
    assert_nil LiveResource.find(:class_1, :alf)

    proxy = LiveResource.find(:class_1) do |name|
      name == "bob" ? name : nil
    end

    assert_equal "bob", proxy.redis_name
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

    assert !i.respond_to?(:method23), "instance should not respond to method23"
    assert !i.respond_to?(:method23!), "instance should not respond to method23!"
    assert !i.respond_to?(:method23?), "instance should not respond to method23?"
  end

  def test_message_path
    assert_equal 5, LiveResource::find(:class_1, :bob).method1(2, 3)
  end
end
