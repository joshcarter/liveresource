require File.join(File.dirname(__FILE__), 'test_helper')

class FancyClass
  attr_reader :value

  def initialize(value)
    @value = value
  end
end

class RedisSpaceTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end

  def test_method_get_set_with_same_key
    logger = Logger.new(STDOUT)
    logger.level = Logger::WARN
    rs = LiveResource::RedisSpace.new('test', logger)

    # Set with same token, differing keys
    rs.method_set 123, 'key 1', 'value 1'
    rs.method_set 123, 'key 2', FancyClass.new(42)

    assert_equal 'value 1', rs.method_get(123, 'key 1')
    assert_equal 42, rs.method_get(123, 'key 2').value
  end
  
  def test_method_tokens_independent
    rs = LiveResource::RedisSpace.new('test')
    
    # Set several value, same keys but different tokens
    rs.method_set 1, 'key', 'value 1'
    rs.method_set 2, 'key', 'value 2'
    rs.method_set 3, 'key', 'value 3'
    
    assert_equal 'value 1', rs.method_get(1, 'key')
    assert_equal 'value 2', rs.method_get(2, 'key')
    assert_equal 'value 3', rs.method_get(3, 'key')
  end
  
  def test_method_set_exclusive
    rs = LiveResource::RedisSpace.new('test')

    assert_equal true, rs.method_set_exclusive(1, 'key', 'value 1')
    assert_equal false, rs.method_set_exclusive(1, 'key', 'value 2')
  end
end