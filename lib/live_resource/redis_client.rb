require 'rubygems'
require 'redis'
require 'yaml'
require_relative 'log_helper'
require_relative 'redis_client/attributes'
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
    attr_reader :redis_class, :redis_name

    @@logger = Logger.new(STDERR)
    @@logger.level = Logger::WARN

    def initialize(resource_class, resource_name)
      @redis_class = RedisClient.redisized_key(resource_class)
      @redis_name = RedisClient.redisized_key(resource_name)

      self.logger = self.class.logger
    end

    def method_missing(method, *params, &block)
      if self.class.redis.respond_to? method
        redis_command(method, params, &block)
      else
        super
      end
    end

    def respond_to?(method)
      return true if self.class.redis.respond_to?(method)
      super
    end

    # Override default (Ruby) exec with Redis exec.
    def exec
      redis_command(:exec, nil)
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
      @@logger
    end

    def self.logger=(logger)
      @@logger = logger
    end

    def self.redisized_key(word)
      word = word.to_s.dup
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.gsub!('::', '-')
      word.downcase!
      word
    end

    private

    def redis_command(method, params, &block)
      debug ">>", method.to_s, *params
      response = self.class.redis.send(method, *params, &block)
      debug "<<", response
      response
    end

    def is_class?
      @redis_class == "class"
    end
  end
end
