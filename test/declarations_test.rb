require_relative 'test_helper'

class TestClass < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    @@class_attr = 42

    remote_reader :name
    remote_writer :write_only
    remote_accessor :accessor

    resource_name :name
    resource_class :class_1

    def initialize(name)
      remote_attribute_write(:name, name)

      self.write_only = 'not yet written'
      self.accessor = nil
    end

    def self.class_method1(param1, param2)
      (param1 + param2).upcase
    end

    def method1(param1, param2)
      name + param1 + param2
    end

    def self.class_attr
      @@class_attr
    end

    def self.class_attr=(new_value)
      @@class_attr = new_value
    end

    def self.private_class_method1
    end
    private_class_method :private_class_method1

    private

    def private_method1
    end
  end

  def setup
    flush_redis

    LiveResource::RedisClient.logger.level = Logger::INFO

    # Class resources
    LiveResource::register(Class1).start
  end

  def teardown
    LiveResource::stop
  end

  def test_correct_class_methods
    assert_equal [:new, :ruby_new, :class_method1, :class_attr, :class_attr=].sort,
    Class1.remote_methods.sort
  end

  # TODO: support class attributes (?)
  # def test_correct_class_attributes
  #   assert_equal [:class_attr], Class1.remote_attributes
  # end

  def test_correct_instance_methods
    assert_equal [:delete, :method1], Class1.ruby_new("foo").remote_methods
  end

  def test_correct_instance_attributes
    assert_equal [:name, :write_only=, :accessor, :accessor=].sort,
    Class1.ruby_new("foo").remote_attributes.sort
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

  def test_new_returns_resource_proxy
    class_resource = LiveResource::find(:class_1)
    bob = class_resource.new("bob")

    assert_equal "bob jones", bob.method1(" ", "jones")
  end

  def test_resource_proxy_can_get_attributes
    class_resource = LiveResource::find(:class_1)
    bob = class_resource.new("bob")

    assert_equal "bob", bob.name
    assert_equal nil, bob.accessor

    bob.accessor = "new value"
    assert_equal "new value", bob.accessor
  end
end
