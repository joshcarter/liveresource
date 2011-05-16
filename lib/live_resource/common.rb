require File.join(File.dirname(__FILE__), 'log_helper')
require File.join(File.dirname(__FILE__), 'redis_space')

module LiveResource
  module Common
    include LogHelper

    attr_accessor :namespace
    
    def redis=(redis)
      if @redis_space.nil?
        debug "Creating RedisSpace with client-provided #{redis.inspect}"
        @redis_space = RedisSpace.new(namespace, logger, redis)
      else
        debug "Updating RedisSpace with client-provided #{redis.inspect}"
        @redis_space.redis = redis
      end
    end
    
    def redis_space
      if @redis_space.nil?
        debug "Creating RedisSpace with default Redis client"
        @redis_space = RedisSpace.new(namespace, logger)
      end
      
      @redis_space
    end
  end
end
