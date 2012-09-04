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
