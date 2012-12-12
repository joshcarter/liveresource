require_relative 'test_helper'

class FindersTest < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    remote_reader :name
    remote_reader :value

    resource_name :name
    resource_class :class_1

    def initialize(name, value)
      remote_attribute_write(:name, name)
      remote_attribute_write(:value, value)
    end
  end

  def setup
    Redis.new.flushall

    LiveResource::RedisClient.logger.level = Logger::INFO

    # Class resources
    class_resource = LiveResource::register(Class1).start

    # Instances
    class_resource.new("foo", 13)
    class_resource.new("bar", 23)
    class_resource.new("baz", 23)
  end

  def teardown
    LiveResource::shutdown
  end

  def test_find_class
    class_resource = LiveResource::find(:class_1)
    assert_not_nil class_resource
    assert_equal "class", class_resource.redis_class
    assert_equal "class_1", class_resource.redis_name
  end

  def test_find_class_no_match
    class_resource = LiveResource::find(:bogus_class)
    assert_nil class_resource
  end

  def test_find_resource_with_name
    resource = LiveResource::find(:class_1, "foo")
    assert_not_nil resource
    assert_equal "class_1", resource.redis_class
    assert_equal "foo", resource.redis_name
    assert_equal "foo", resource.name
  end

  def test_find_resource_with_name_no_match
    resource = LiveResource::find(:class_1, "bogus_name")
    assert_nil resource
  end

  def test_find_resource_with_block
    resource = LiveResource::find(:class_1) do |name|
      name.start_with? "f"
    end
    assert_not_nil resource
    assert_equal "class_1", resource.redis_class
    assert_equal "foo", resource.redis_name
    assert_equal "foo", resource.name
  end

  def test_find_resource_with_block_no_match
    resource = LiveResource::find(:class_1) do |name|
      name.include? "bogus_name"
    end
    assert_nil resource
  end

  def test_any
    resource = LiveResource::any(:class_1)
    assert_not_nil resource
    assert_equal "class_1", resource.redis_class
  end

  def test_all
    resources = LiveResource::all(:class_1)
    assert resources.is_a? Array
    assert_equal 3, resources.length 
    resources.each do |r|
      assert_equal "class_1", r.redis_class
    end
  end

  def test_find_all
    resources = LiveResource::find_all(:class_1) do |r|
      r.value == 23
    end
    assert resources.is_a? Array
    assert_equal 2, resources.length 
    resources.each do |r|
      assert_equal "class_1", r.redis_class
      assert_equal 23, r.value
    end
  end

  def test_find_all_no_match
    resources = LiveResource::find_all(:class_1) do |r|
      r.value == 7
    end
    assert resources.is_a? Array
    assert_equal 0, resources.length 
  end

  def test_find_all_no_block
    resources = LiveResource::find_all(:class_1)
    assert resources.is_a? Enumerator
  end
end
