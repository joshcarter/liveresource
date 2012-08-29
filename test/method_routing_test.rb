require_relative 'test_helper'

class MethodRoutingTest < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    resource_class :class_1
    resource_name :object_id

    def method1
      [1]
    end
  end

  class Class2
    include LiveResource::Resource

    resource_class :class_2
    resource_name :object_id

    def method2(a)
      a << 2
    end
  end

  class Class3
    include LiveResource::Resource

    resource_class :class_3
    resource_name :object_id

    def method3(a)
      a << 3
    end
  end

  def test_create_method
    m = LiveResource::Method.new(:method, [], {})
    c1 = LiveResource::any(:class_1)
    c2 = LiveResource::any(:class_2)
    c3 = LiveResource::any(:class_3)

    m << c1
    m << c2
    m << c3

    assert_equal [1, 2, 3], c.remote_send(m)
  end
end
