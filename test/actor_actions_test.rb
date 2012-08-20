require_relative 'test_helper'

class Class1
  include LiveResource::Resource

  attr_reader :name
  resource_name :name

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

  # def method2(param1, param2, param3)    
  #   param1
  # end
end

class Class3
  include LiveResource::Resource

  resource_name :object_id

  # def method3(param1)
  #   param1.upcase
  # end
end

class TestClass < Test::Unit::TestCase
  def setup
    Redis.new.flushall

    LiveResource::redis_logger.level = Logger::DEBUG

    # Class resources
    # LiveResource::register Class1
    # LiveResource::register Class2
    # LiveResource::register Class3

    # Instance resources
    LiveResource::register Class1.new("bob")
    LiveResource::register Class1.new("sue")
    LiveResource::register Class1.new("fred")
    LiveResource::register Class2.new
    LiveResource::register Class3.new

    10.times { Thread.pass } # Let method dispatchers start
  end

  def teardown
    LiveResource::stop
  end

  def test_find_instance
    assert_equal 3, LiveResource::all(:class1).length

    assert_not_nil LiveResource.find(:class1, :fred)
    assert_nil LiveResource.find(:class1, :alf)
  end

  def test_instances_have_methods
    i = LiveResource::all(:class1).first

    assert i.respond_to?(:method1), "instance does not respond to method1"
  end

  # def test_message_path
    # v = LiveResource::any(:class_1).method1? "foo", "bar"
    #
    # assert_equal "FOO", v.value
  # end
end
