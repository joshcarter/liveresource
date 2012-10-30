require_relative 'test_helper'

class AttributeTest < Test::Unit::TestCase
  class MyClass
    attr_accessor :a, :b

    def initialize(a, b)
      @a = a
      @b = b
    end
  end

  class AttributeProvider
    include LiveResource::Resource

    resource_class :attribute_provider
    resource_name :object_id

    remote_accessor :string, :integer, :float, :my_class, :nil

    def initialize
      self.string = "string"
      self.integer = 42
      self.float = 3.14
      self.my_class = MyClass.new("foo", 42)
      self.nil = nil
    end
  end

  def setup
    Redis.new.flushall

    LiveResource::RedisClient.logger.level = Logger::INFO

    AttributeProvider.new
  end

  def teardown
    LiveResource::stop
  end

  def test_string_attribute
    ap = LiveResource::any(:attribute_provider)

    assert ap.string.kind_of?(String), "String attribute is not a string"
    assert_equal "string", ap.string

    ap.string = "new string"
    assert_equal "new string", ap.string
  end

  def test_numeric_attributes
    ap = LiveResource::any(:attribute_provider)

    assert ap.integer.kind_of?(Numeric), "Integer attribute is not a numeric"
    assert ap.float.kind_of?(Numeric), "Float attribute is not a numeric"
    assert ap.float.kind_of?(Float), "Float attribute is not a float"

    assert_equal 42, ap.integer
    assert_equal 3.14, ap.float

    ap.integer = 24
    assert_equal 24, ap.integer
  end

  def test_custom_attribute
    ap = LiveResource::any(:attribute_provider)
    mc = ap.my_class

    assert mc.kind_of?(MyClass), "MyClass attribute is not a MyClass"

    assert_equal "foo", mc.a
    assert_equal 42, mc.b
  end

  def test_nil_attribute
    ap = LiveResource::any(:attribute_provider)

    assert_equal nil, ap.nil
  end
end

class AttributeModifyTest < Test::Unit::TestCase
  class Incrementer
    include LiveResource::Resource

    resource_class :incrementer
    resource_name :object_id

    remote_accessor :value1, :value2

    def initialize(value1, value2)
      self.value1 = value1
      self.value2 = value2
    end

    def increment(*values)
      remote_modify(*values) do |a, v|
        v + 1
      end
    end

    def increment_with_interference
      modified = false
      remote_modify(:value1, :value2) do |a, v|
        # modify the value from a different redis the
        # first time through
        unless modified
          self.redis.clone.attribute_write(a, 10, {})
          modified = true
        end
        v + 1
      end
    end
  end

  def setup
    Redis.new.flushall

    LiveResource::RedisClient.logger.level = Logger::INFO

    Incrementer.new(1, 1)
  end

  def teardown
    LiveResource::stop
  end

  def test_modify_without_interference
    i = LiveResource::any(:incrementer)

    assert_equal 1, i.value1

    i.increment(:value1)

    assert_equal 2, i.value1
  end

  def test_multi_modify_without_interference
    i = LiveResource::any(:incrementer)

    assert_equal 1, i.value1
    assert_equal 1, i.value2

    i.increment(:value1, :value2)

    assert_equal 2, i.value1
    assert_equal 2, i.value2
  end

  def test_modify_with_interference
    i = LiveResource::any(:incrementer)

    assert_equal 1, i.value1
    assert_equal 1, i.value2

    i.increment_with_interference

    # Because of the interference, we should now be at 10
    # for value1 but still only be at 2 for value2
    assert_equal 11, i.value1
    assert_equal 2, i.value2
  end

  def test_modify_invalid_attributes
    i = LiveResource::any(:incrementer)

    # Just a single invalid attr
    assert_raise(ArgumentError) do
      i.increment(:value3)
    end

    # Now two
    assert_raise(ArgumentError) do
      i.increment(:value3, :value4)
    end

    # Now mix with a valid attr
    assert_raise(ArgumentError) do
      i.increment(:value1, :value3)
    end
  end
end
