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

    def method2(i)
      [i, 2]
    end
  end

  class Class3
    include LiveResource::Resource

    resource_class :class_3
    resource_name :object_id

    def method3(i, j)
      [i, j, 3]
    end
  end

  def setup
    Redis.new.flushall
    Class1.new
    Class2.new
    Class3.new
  end

  def teardown
    LiveResource::stop
  end

  def test_create_method
    m = LiveResource::RemoteMethod.new(:method => :method1)
    c1 = LiveResource::any(:class_1)
    c2 = LiveResource::any(:class_2)
    c3 = LiveResource::any(:class_3)

    m.add_destination(c2, :method2, [])
    m.add_destination(c3, :method3, [])

    assert_equal [1, 2, 3], c1.wait_for_done(c1.remote_send(m))
  end
end
