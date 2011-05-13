require File.join(File.dirname(__FILE__), 'test_helper')

class C
  # NOTE: normal clients would never include Base directly, they would 
  # include Attribute, Method, or such instead.
  include LiveResource::Base
end

class BaseTest < Test::Unit::TestCase
  def test_redis_space_created_dynamically
    assert_not_nil C.new.redis_space
  end

  def test_can_provide_own_redis
    redis = mock()
    
    c = C.new
    c.redis = redis

    assert_equal redis, c.redis_space.instance_variable_get(:@redis)
  end
  
  def test_replace_redis_later
    redis = mock()
    
    c = C.new
    assert_instance_of Redis, c.redis_space.instance_variable_get(:@redis)

    c.redis = redis
    assert_equal redis, c.redis_space.instance_variable_get(:@redis) 
  end
end