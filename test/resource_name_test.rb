require_relative 'test_helper'

class ResourceNameTest < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    resource_class :class_1
    resource_name :name

    remote_reader :name

    def initialize(name)
      remote_attribute_write(:name, name)
    end
  end

  class Class2
    include LiveResource::Resource

    resource_class :class_2
    resource_name :name_method

    remote_reader :name

    def initialize(name)
      remote_attribute_write(:name, name)
    end

    def name_method
      # This won't work!
      #
      # In order to get the name attribute, we have to already know the
      # name of the resource (but this method is trying to get the name
      # of the resource). Chicken. Egg.
      self.name
    end
  end

  def setup
    flush_redis

    LiveResource::RedisClient.logger.level = Logger::INFO

    LiveResource::register(Class1).start
    LiveResource::register(Class2).start
  end

  def teardown
    LiveResource::stop
  end

  def test_resource_name_based_on_remote_attr
    c1 = LiveResource::find(:class_1)
    c1_instance = c1.new("foo")

    # Make sure we can find it by the name
    assert_not_nil LiveResource::find(:class_1, "foo")

    # Check the name
    assert_equal "foo", c1_instance.name
  end

  def test_resource_name_circular_dependency
    assert_raise RuntimeError do
      LiveResource::find(:class_2).new("foo")
    end
  end
end
