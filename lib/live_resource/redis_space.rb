require 'rubygems'
require 'redis'
require 'yaml'
require File.join(File.dirname(__FILE__), 'log_helper')

module LiveResource
  class RedisSpace
    include LogHelper
    
    def initialize(namespace, logger = nil, *redis_params)
      @namespace = namespace
      @redis = Redis.new(*redis_params)
      initialize_logger(logger)
    end

    def method_set_exclusive(token, key, value)
      params = ["#{@namespace}.methods.#{token}", key, serialize(value)]
      debug "hsetnx", params
      @redis.hsetnx *params
    end
    
    def method_set(token, key, value)
      params = ["#{@namespace}.methods.#{token}", key, serialize(value)]
      debug "hset", params
      @redis.hset *params
    end
    
    def method_get(token, key)
      params = ["#{@namespace}.methods.#{token}", key]
      value = @redis.hget(*params)
      debug "hget", params, "-->", value
      deserialize value
    end
    
    def result_set(token, result)
      params = ["#{@name}.results.#{token}", serialize(result)]
      debug "lpush", params
      @redis.lpush *params
    end
    
  private
  
    def serialize(value)
      if value.is_a? Exception
        # YAML can't dump an exception properly, it loses the message.
        # Save that separately as a string.
        YAML::dump [value, value.message]
      else
        YAML::dump value
      end
    end
  
    def deserialize(value)
      YAML::load value
    end
  end
end