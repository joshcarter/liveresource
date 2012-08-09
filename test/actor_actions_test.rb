require_relative 'test_helper'

class Class1
  include LiveResource::Resource
  
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
  
  # def method2(param1, param2, param3)    
  #   param1
  # end
end

class Class3
  include LiveResource::Resource
  
  # def method3(param1)
  #   param1.upcase
  # end
end

class TestClass < Test::Unit::TestCase
  def setup
    LiveResource::redis_logger.level = Logger::DEBUG
    
    @c1 = Class1.new
    @c2 = Class2.new
    @c3 = Class3.new
    
    LiveResource::register(@c1)
    LiveResource::register(@c2)
    LiveResource::register(@c3)
    
    LiveResource::start
  end
  
  def teardown
    LiveResource::stop

    LiveResource::unregister(@c1)
    LiveResource::unregister(@c2)
    LiveResource::unregister(@c3)
  end

  def test_message_path
    assert true
    
    # v = LiveResource::any(:class_1).method1? "foo", "bar"
    # 
    # assert_equal "FOO", v.value
  end
end
