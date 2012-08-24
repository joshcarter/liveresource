require_relative 'test_helper'

class TestClass < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    attr_reader :name
    resource_name :name
    resource_class :class_1

    def initialize(name)
      @name = name
    end

    class << self
      alias :ruby_new :new
    end

    def self.new(name)
      obj = ruby_new(name)
      LiveResource::register obj

      # Could we return an resource proxy here?
      true
    end

    def self.class_method1(param1, param2)
      (param1 + param2).upcase
    end

    def method1(param1, param2)
      param1 + param2
    end

    def self.private_class_method1
    end
    private_class_method :private_class_method1

    private
    def private_method1
    end
  end

  def setup
    Redis.new.flushall

    LiveResource::RedisClient.logger.level = Logger::INFO

    # Class resources
    LiveResource::register Class1
  end

  def teardown
    LiveResource::stop
  end

  def test_correct_remote_class_methods
    assert_equal [:new, :ruby_new, :class_method1].sort, Class1.remote_methods.sort

    assert_equal [:method1, :name].sort, Class1.ruby_new("foo").remote_methods.sort
  end

  def test_call_class_method
    class_resource = LiveResource::find(:class_1)

    assert class_resource.respond_to? :new
    assert class_resource.respond_to? :class_method1

    assert_equal "FOOBAR", class_resource.class_method1("foo", "bar")
  end

  def test_create_instances
    class_resource = LiveResource::find(:class_1)

    assert_equal 0, LiveResource::all(:class_1).length

    class_resource.new("bob")
    class_resource.new("fred")
    class_resource.new("sue")

    assert_equal 3, LiveResource::all(:class_1).length
  end
end
