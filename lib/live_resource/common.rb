require File.join(File.dirname(__FILE__), 'log_helper')
require File.join(File.dirname(__FILE__), 'redis_space')

module LiveResource
  module Common
    include LogHelper

    attr_accessor :namespace

    def redis=(redis)
      # Hash of Thread -> RedisSpace instances
      @redis_spaces ||= {}
      
      if @proto_redis_space.nil?
        debug "Creating RedisSpace with client-provided #{redis.object_id}"
        @proto_redis_space = RedisSpace.new(namespace, logger, redis)
      else
        debug "Updating RedisSpace with client-provided #{redis.object_id}"
        @proto_redis_space.redis = redis
      end
      
      @redis_spaces[Thread.current] = @proto_redis_space.clone
    end
    
    def redis_space
      # Hash of Thread -> RedisSpace instances
      @redis_spaces ||= {}

      if @redis_spaces[Thread.current].nil?
        if @proto_redis_space.nil?
          debug "Creating RedisSpace with default Redis client"
          @proto_redis_space = RedisSpace.new(namespace, logger)
        end

        @redis_spaces[Thread.current] = @proto_redis_space.clone
      end
      
      @redis_spaces[Thread.current]
    end
  end
end
