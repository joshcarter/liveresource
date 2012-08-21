require 'rubygems'
require 'redis'
require 'yaml'
require_relative 'log_helper'
require_relative 'redis_client/methods'
require_relative 'redis_client/registration'

class Redis
  def clone
    # Create independent Redis
    Redis.new(
          :host => client.host,
          :port => client.port,
          :timeout => client.timeout,
          :logger => client.logger,
          :password => client.password,
          :db => client.db)
  end
end

module LiveResource
  class RedisClient
    include LogHelper
    attr_writer :redis

    def initialize(resource_class, resource_name)
      @redis_class = redisized_key(resource_class)
      @redis_name = redisized_key(resource_name)
      @logger = self.class.logger

      info("new redis client: #{resource_class} -> #{@redis_class}, #{resource_name} ->#{@redis_name}")
    end

    def method_missing(method, *params, &block)
      if self.class.redis.respond_to? method
        debug ">>", method.to_s, *params
        response = self.class.redis.send(method, *params, &block)
        debug "<<", response
        response
      else
        super
      end
    end

    def respond_to?(method)
      return true if self.class.redis.respond_to?(method)
      super
    end

    def self.redis
      # Hash of Thread -> Redis instances
      @@redis ||= {}
      @@proto_redis ||= Redis.new

      if @@redis[Thread.current].nil?
        @@redis[Thread.current] = @@proto_redis.clone
      end

      @@redis[Thread.current]
    end

    def self.redis=(redis)
      @@proto_redis = redis
      @@redis = {}
    end

    def self.logger
      @@logger ||= Logger.new(STDERR)
      @@logger
    end

    def self.logger=(logger)
      @@logger = logger
    end

    private

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
end
