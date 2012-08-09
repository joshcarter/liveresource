require_relative 'test_helper'

class FancyClass
  attr_reader :value

  def initialize(value)
    @value = value
  end
end

class RedisClientTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end

  def test_global_redis_space
    assert_equal LiveResource::RedisClient, LiveResource::redis.class
  end

  # def test_method_get_set_with_same_key
  #   rc = mock()
  #   rc.expects :attribute_set, "--- 123\n...\n"
  # 
  # 
  #   logger = Logger.new(STDOUT)
  #   logger.level = Logger::WARN
  #   r = LiveResource::Client.new('test', logger)
  # 
  #   # Set with same token, differing keys
  #   rs.method_set 123, 'key 1', 'value 1'
  #   rs.method_set 123, 'key 2', FancyClass.new(42)
  # 
  #   assert_equal 'value 1', rs.method_get(123, 'key 1')
  #   assert_equal 42, rs.method_get(123, 'key 2').value
  # end
  # 
  # def test_method_tokens_independent
  #   rs = LiveResource::RedisSpace.new('test')
  #   
  #   # Set several value, same keys but different tokens
  #   rs.method_set 1, 'key', 'value 1'
  #   rs.method_set 2, 'key', 'value 2'
  #   rs.method_set 3, 'key', 'value 3'
  #   
  #   assert_equal 'value 1', rs.method_get(1, 'key')
  #   assert_equal 'value 2', rs.method_get(2, 'key')
  #   assert_equal 'value 3', rs.method_get(3, 'key')
  # end
  # 
  # def test_method_set_exclusive
  #   rs = LiveResource::RedisSpace.new('test')
  # 
  #   assert_equal true, rs.method_set_exclusive(1, 'key', 'value 1')
  #   assert_equal false, rs.method_set_exclusive(1, 'key', 'value 2')
  # end
  # 
  # def test_method_push_pop_simple
  #   rs = LiveResource::RedisSpace.new('test')
  #   assert_equal 0, Redis.new.dbsize
  #   
  #   rs.method_push '1'
  #   assert_equal 1, Redis.new.dbsize
  # 
  #   token = rs.method_wait
  #   assert_equal '1', token
  #   
  #   rs.method_done token
  #   assert_equal 0, Redis.new.dbsize    
  # end
  # 
  # def test_method_push_pop_multiple
  #   rs = LiveResource::RedisSpace.new('test')
  #   assert_equal 0, Redis.new.dbsize
  #   
  #   rs.method_push '1'
  #   rs.method_push '2'
  #   rs.method_push '3'
  #   
  #   assert_equal ['3', '2', '1'], rs.method_tokens_waiting
  #   assert_equal [], rs.method_tokens_in_progress
  # 
  #   assert_equal '1', rs.method_wait
  #   assert_equal '2', rs.method_wait
  #   assert_equal '3', rs.method_wait
  # 
  #   assert_equal [], rs.method_tokens_waiting
  #   assert_equal ['3', '2', '1'], rs.method_tokens_in_progress
  # 
  #   # Redis should have one key here (the methods_in_progress list)
  #   assert_equal 1, Redis.new.dbsize
  # 
  #   # Now start marking methods done; after the last one, the key 
  #   # count should go down to zero.
  #   rs.method_done '1'
  #   assert_equal 1, Redis.new.dbsize
  #   rs.method_done '2'
  #   assert_equal 1, Redis.new.dbsize
  #   rs.method_done '3'
  #   assert_equal 0, Redis.new.dbsize    
  # end
  # 
  # def test_serializes_exceptions_properly
  #   rs = LiveResource::RedisSpace.new('test')
  # 
  #   rs.method_set('1', 'key', 'value') # just need something there
  #   rs.result_set('1', RuntimeError.new('foo'))    
  #   result = rs.result_get '1'
  #   
  #   assert_equal RuntimeError, result.class
  #   assert_equal 'foo', result.message
  # end
  # 
  # def test_find_token_in_lists
  #   r = Redis.new
  #   rs = LiveResource::RedisSpace.new('test')
  # 
  #   r.lpush('test.methods', '1')
  #   r.lpush('test.methods_in_progress', '2')
  #   r.lpush('test.results.3', 'result')
  #   
  #   assert_equal :methods, rs.find_token('1')
  #   assert_equal :methods_in_progress, rs.find_token('2')
  #   assert_equal :results, rs.find_token('3')
  #   assert_equal nil, rs.find_token('4')
  # end  
end

