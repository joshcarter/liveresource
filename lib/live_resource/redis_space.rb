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

      debug "RedisSpace created for namespace #{namespace.inspect}, Redis #{redis.object_id}"
    end
    
    def clone
      client = @redis.client
      
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
      debug "watch (attribute_watch)", key
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

      # Older versions of Redis return 1/0 instead of true/false.
      # Normalize the return values to true/false since 'if 0' is
      # true in Ruby.
      result = @redis.hsetnx *params
      result = true if result == 1
      result = false if result == 0
      result
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
      # Need to watch the method while setting the result; if the caller 
      # has given up waiting before we set the result, we don't want to
      # leave extra crud in Redis.
      params = ["#{@namespace}.methods.#{token}"]
      debug "watch (result_set)", params
      @redis.watch *params

      unless @redis.exists("#{@namespace}.methods.#{token}")
        # Caller must have deleted method
        debug "unwatch"
        @redis.unwatch
        return
      end
      
      begin
        debug "multi (result_set)"
        @redis.multi
      
        params = ["#{@namespace}.results.#{token}", serialize(result)]
        debug "lpush", params
        @redis.lpush *params
      
        result = @redis.exec
        debug "exec", "-->", result
      rescue RuntimeError => e
        # Must have been deleted while we were working on it, bail out.
        warn e
        debug "discard"
        @redis.discard
      end

      # params = ["#{@namespace}.results.#{token}", serialize(result)]
      # debug "lpush", params
      # @redis.lpush *params

    end

    def result_get(token, timeout = 0)
      unless timeout.is_a?(Integer)
        raise ArgumentError.new("timeout #{timeout} must be an integer")
      end
      
      params = ["#{@namespace}.results.#{token}", timeout]
      list, result = @redis.brpop *params
      debug "brpop", params, "-->", result.inspect
      
      if result.nil?
        raise RuntimeError.new("timed out waiting for method #{token}")
      end
      
      deserialize(result)
    end
    
    def find_token(token)
      token = token.to_s
      
      # Need to do a multi/exec so we can atomically look in 3 lists
      # for the token
      debug "multi (find_token)"
      @redis.multi
      @redis.lrange("#{@namespace}.methods", 0, -1)
      @redis.lrange("#{@namespace}.methods_in_progress", 0, -1)
      @redis.lrange("#{@namespace}.results.#{token}", 0, -1)
      result = @redis.exec
      debug "bulk", "-->", result
      
      return :methods if result[0].include?(token)
      return :methods_in_progress if result[1].include?(token)
      return :results if (result[2] != [])
      
      nil
    end

    def delete_token(token)
      token = token.to_s
      
      # Need to do a multi/exec so we can atomically delete from all 3 lists
      debug "multi (delete_token)"
      @redis.multi
      @redis.lrem("#{@namespace}.methods", 0, token)
      @redis.lrem("#{@namespace}.methods_in_progress", 0, token)
      @redis.lrem("#{@namespace}.results.#{token}", 0, token)
      result = @redis.exec
      debug "bulk", "-->", result
    end
       
  private
  
    def serialize(value)
      if value.is_a? Exception
        # YAML can't dump an exception properly, it loses the message.
        # and the backtrace.  Save those separately as strings.
        YAML::dump [value, value.message, value.backtrace]
      else
        YAML::dump value
      end
    end
  
    def deserialize(value)
      raise "Cannot deserialize nil value" if value.nil?
      
      result = YAML::load(value)
      
      if result.is_a?(Array) and result[0].is_a?(Exception)
        # Inverse of what serialize() is doing with exceptions.
        e = result[0].class.new(result[1])
        e.set_backtrace result[2]
        result = e
      end
      
      result
    end
  end
end
