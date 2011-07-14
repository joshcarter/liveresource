require File.join(File.dirname(__FILE__), 'test_helper')

class C
  # NOTE: normal clients would never include Common directly, they would 
  # include Attribute, Method, or such instead.
  include LiveResource::Common
end

class CommonTest < Test::Unit::TestCase
  def test_redis_space_created_dynamically
    assert_not_nil C.new.redis_space
  end

  def test_can_provide_own_redis
    c = C.new
    c.redis = Redis.new(:password => 'foo')

    assert_equal 'foo', c.redis_space.instance_variable_get(:@redis).client.password
  end
  
  def test_replace_redis_later
    redis = Redis.new
    
    c = C.new
    assert_equal nil, c.redis_space.instance_variable_get(:@redis).client.password

    c.redis = Redis.new(:password => 'foo')
    assert_equal 'foo', c.redis_space.instance_variable_get(:@redis).client.password
  end
  
  def test_separate_threads_have_separate_spaces
    thread_map = {}
    threads = []
    c = C.new
    
    # Even though we're using the same instance of c, each thread should
    # get a different RedisSpace.

    c.redis_space # Prime redis_space attribute

    10.times do
      threads << Thread.new do
        thread_map[Thread.current] = c.redis_space.object_id
      end
    end

    threads.each { |t| t.join }

    assert_not_nil thread_map[threads[0]]
    assert_not_equal thread_map[threads[0]], thread_map[threads[1]]
    assert_not_equal thread_map[threads[1]], thread_map[threads[2]]    
  end
end