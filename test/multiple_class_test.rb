require_relative 'test_helper'

class ClassMethodTest < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    resource_class :class_1
    resource_name :object_id

    def self.class_method_1
      "42"
    end
  end

  class Class2
    include LiveResource::Resource

    resource_class :class_2
    resource_name :object_id

    def self.class_method_2
      "foo"
    end
  end

  def setup
    Redis.new.flushall

    LiveResource::register(Class1).start
    LiveResource::register(Class2).start
  end

  def teardown
    LiveResource::stop
  end

  def test_classes_dont_conflict
    c1 = LiveResource::find(:class_1)
    c2 = LiveResource::find(:class_2)

    assert_equal true,  c1.respond_to?(:class_method_1)
    assert_equal false, c1.respond_to?(:class_method_2)

    assert_equal true,  c2.respond_to?(:class_method_2)
    assert_equal false, c2.respond_to?(:class_method_1)
  end
end
