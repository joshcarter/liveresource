require 'redis'
require_relative 'methods'
require_relative 'registration'

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
