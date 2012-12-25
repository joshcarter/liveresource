require_relative 'test_helper'

class Tagger
  include LiveResource::ErrorHelper
  
  def raises_generic_error
    tag_errors do
      raise "I don't feel well"
    end
  end

  def raises_redis_error
    tag_errors(LiveResource::RedisError) do
      raise Redis::CannotConnectError, "I'm a Redis error"
    end
  end
end

class ErrorTaggingTest < Test::Unit::TestCase
  def setup
    @tagger = Tagger.new
  end

  def test_generic_tag
    # Clients may rescue base exception class.
    assert_raise(RuntimeError) do
      @tagger.raises_generic_error
    end

    # Or, rescue the LiveResource-specific error.
    assert_raise(LiveResource::Error) do
      @tagger.raises_generic_error
    end    
  end
  
  def test_specific_tag
    # Rescue exception class
    assert_raise(Redis::CannotConnectError) do
      @tagger.raises_redis_error
    end

    # Should still have the LiveResource base error tag
    assert_raise(LiveResource::Error) do
      @tagger.raises_redis_error
    end    

    # Should also have the more specific error.
    assert_raise(LiveResource::RedisError) do
      @tagger.raises_redis_error
    end    
  end
end