require_relative 'test_helper'

class RedisClientTest < Test::Unit::TestCase
  def test_tests_use_non_standard_db
    requested_db = ENV['LIVERESOURCE_DB']
    assert_not_nil requested_db

    current_db = LiveResource::RedisClient.redis.client.db 
    assert !current_db.zero?
  end

  def test_uses_db_env_variable
    requested_db = ENV['LIVERESOURCE_DB']
    assert_not_nil requested_db

    requested_db = requested_db.to_i

    current_db = LiveResource::RedisClient.redis.client.db 
    assert_equal requested_db, current_db
  end
end
