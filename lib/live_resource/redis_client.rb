require 'rubygems'
require 'redis'
require 'yaml'
require_relative 'log_helper'

module LiveResource
  module HasRedisClient
    def redis
      LiveResource::redis
    end

    # Class-level redis class name
    def self.redis_class
      "class"
    end

    # Instance-level redis class name
    def redis_class
      redisized_key(self.class.to_s)
    end

    # Class-level redis object name
    def self.redis_name
      redisized_key(self.to_s)
    end

    # Instance-level redis object name
    def redis_name
      redisized_key(self.resource_name)
    end

    def redisized_key(word)
      word = word.to_s.dup
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.gsub!('::', '-')
      word.downcase!
      word
    end
  end

  def self.redis=(redis)
    # Hash of Thread -> RedisClient instances
    @redis_clients ||= {}

    if @proto_redis_client.nil?
      # debug "Creating RedisClient with client-provided #{redis.object_id}"
      @proto_redis_client = RedisClient.new(redis)
    else
      # debug "Updating RedisClient with client-provided #{redis.object_id}"
      @proto_redis_client.redis = redis
    end

    @redis_clients[Thread.current] = @proto_redis_client.clone
  end

  def self.redis
    # Hash of Thread -> RedisClient instances
    @redis_clients ||= {}

    if @redis_clients[Thread.current].nil?
      if @proto_redis_client.nil?
        # debug "Creating RedisClient with default Redis client"
        @proto_redis_client = RedisClient.new
      end

      @redis_clients[Thread.current] = @proto_redis_client.clone
    end

    @redis_clients[Thread.current]
  end

  def self.redis_logger
    @redis_logger ||= Logger.new(STDERR)
    @redis_logger
  end

  def self.redis_logger=(logger)
    @redis_logger = logger
  end
end

module LiveResource
  class RedisClient
    include LogHelper
    attr_writer :redis

    def initialize(redis = Redis.new)
      @redis = redis
      @logger = LiveResource::redis_logger

      debug "RedisClient created for Redis #{redis.client.host}:#{redis.client.port} (id #{redis.object_id})"
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

      RedisClient.new(new_redis)
    end

    def methods_list(resource)
      "#{resource.redis_class}.#{resource.redis_name}.methods"
    end

    def methods_in_progress_list(resource)
      "#{resource.redis_class}.#{resource.redis_name}.methods-in-progress"
    end

    def method_wait(resource)
      brpoplpush methods_list(resource), methods_in_progress_list(resource), 0
    end

    def method_push(resource, token)
      lpush methods_list(resource), token
    end

    def method_done(resource, token)
      lrem methods_in_progress_list(resource), 0, token
    end

    def method_missing(method, *params, &block)
      if @redis.respond_to? method
        debug ">>", method.to_s, *params
        response = @redis.send(method, *params, &block)
        debug "<<", response
        response
      else
        super
      end
    end

    def respond_to?(method)
      return true if @redis.respond_to?(method)
      super
    end
  end
end
