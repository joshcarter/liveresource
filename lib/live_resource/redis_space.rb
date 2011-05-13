require 'rubygems'
require 'redis'
require 'yaml'
require File.join(File.dirname(__FILE__), 'log_helper')

module LiveResource
  class RedisSpace
    include LogHelper
    attr_writer :redis
    
    def initialize(namespace, logger = nil, redis = Redis.new)
      @namespace = namespace
      @redis = redis
      self.logger = logger if logger

      debug "RedisSpace created for namespace #{namespace.inspect}, Redis #{redis.inspect}"
    end
    
    def clone
      client = @saved_redis_client ? @saved_redis_client : @redis.client
      
      # Create independent Redis
      new_redis = Redis.new(
        :host => client.host,
        :port => client.port,
        :timeout => client.timeout,
        :logger => client.logger,
        :password => client.password,
        :db => client.db)
      
      RedisSpace.new(@namespace, self.logger, new_redis)
    end
    
    def attribute_set(key, value)
      key = "#{@namespace}.#{key}"
      value = YAML::dump(value)

      # Don't publish duplicate states
      return if (value == @redis[key])    

      debug "set", key, value
      @redis[key] = value

      debug "publish", key, value
      @redis.publish key, value

      value
    end
    
    def attribute_get(key)
      value = @redis["#{@namespace}.#{key}"]
      debug "get", key, value

      value.nil? ? nil : YAML::load(value)
    end

    def subscribe(keys, &block)
      @saved_redis_client = @redis.client

      keys = keys.map { |key| "#{@namespace}.#{key}"}
      
      debug "subscribe #{keys.inspect}"
      @redis.subscribe(*keys, &block)
    end
    
    def publish(key, value)
      key = "#{@namespace}.#{key}"

      debug "publish #{key} -> #{value}"
      @redis.publish(key, value)
    end
    
    def unsubscribe
      @saved_redis_client = nil
      
      debug "unsubscribe"
      @redis.unsubscribe
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