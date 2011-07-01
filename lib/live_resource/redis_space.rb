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

      # TODO: initialize namespace with something like PID if it's nil.

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
    
    def attribute_set(key, value, options = nil)
      key = "#{@namespace}.#{key}"
      value = YAML::dump(value)

      # Pull out the options we support
      if options
        ttl = options[:ttl]
      end

      # Don't publish duplicate states as long as there's no TTL
      return if (value == @redis[key]) and ttl.nil?

      debug "set", key, value
      @redis[key] = value

      debug "publish", key, value
      @redis.publish key, value

      @redis.expire(key, ttl) if ttl

      value
    end
    
    def attribute_get(key)
      value = @redis["#{@namespace}.#{key}"]
      debug "get", key, value

      value.nil? ? nil : YAML::load(value)
    end
    
    def attribute_watch(key)
      key = "#{@namespace}.#{key}"
      debug "watch", key
      @redis.watch key
    end
    
    def multi
      debug "multi"
      @redis.multi
    end

    def exec
      debug "exec"
      @redis.exec
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
    
    def method_push(token)
      params = ["#{@namespace}.methods", token]
      debug "lpush", params
      @redis.lpush *params
    end
    
    def method_wait
      params = ["#{@namespace}.methods", "#{@namespace}.methods_in_progress", 0]
      debug "brpoplpush", params
      token = @redis.brpoplpush *params
      debug "brpoplpush result=#{token.inspect}", params
      token
    end
    
    def method_done(token)
      params = ["#{@namespace}.methods_in_progress", 0, token]
      debug "lrem", params
      @redis.lrem *params
    end
    
    def method_tokens_waiting
      params = ["#{@namespace}.methods", 0, -1]
      list = @redis.lrange *params
      debug "lrange", params, "-->", list
      list
    end

    def method_tokens_in_progress
      params = ["#{@namespace}.methods_in_progress", 0, -1]
      list = @redis.lrange *params
      debug "lrange", params, "-->", list
      list
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

    def method_delete(token)
      params = ["#{@namespace}.methods.#{token}"]
      debug "del", params
      @redis.del *params
    end
    
    def result_set(token, result)
      params = ["#{@namespace}.results.#{token}", serialize(result)]
      debug "lpush", params
      @redis.lpush *params
    end

    def result_get(token)
      params = ["#{@namespace}.results.#{token}", 0]
      list, result = @redis.brpop *params
      debug "brpop", params, "-->", result
      deserialize(result)
    end
    
    def result_exists?(token)
      params = ["#{@namespace}.results.#{token}"]
      exists = @redis.exists *params
      debug "exists", params, "-->", true
      exists
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
      result = YAML::load(value)
      
      if result.is_a?(Array) and result[0].is_a?(Exception)
        # Inverse of what serialize() is doing with exceptions.
        result = result[0].class.new(result[1])
      end
      
      result
    end
  end
end