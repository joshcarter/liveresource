require_relative 'test_helper'

class Class1
  include LiveResource::Resource

  attr_reader :name
  resource_name :name

  def initialize(name)
    @name = name
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

    @c1 = Class1.new("bob")
    @c2 = Class2.new
    @c3 = Class3.new

    LiveResource::register(@c1)
    LiveResource::register(@c2)
    LiveResource::register(@c3)

    10.times { Thread.pass } # Let method dispatchers start
  end

  def teardown
    LiveResource::stop
  end

  def test_find_instance
    LiveResource::register Class1.new("sue")
    LiveResource::register Class1.new("fred")

    10.times { Thread.pass } # Let method dispatchers start

    puts ">> checking for all class1 instances now <<"

    assert_equal 3, LiveResource::all(:class1).length

    assert_not_nil LiveResource.find(:class1, :fred)
    assert_nil LiveResource.find(:class1, :alf)
  end

  # def test_message_path
    # v = LiveResource::any(:class_1).method1? "foo", "bar"
    #
    # assert_equal "FOO", v.value
  # end
end
