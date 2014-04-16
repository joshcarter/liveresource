require 'rubygems'
require 'redis'
require 'yaml'
require_relative 'error'
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
          :path => client.path,
          :password => client.password,
          :db => client.db)
  end
end

module LiveResource
  class RedisClient
    include LogHelper
    include ErrorHelper
    attr_writer :redis
    attr_reader :redis_class, :redis_name

    DEFAULT_REDIS_DB = 0

    # List of unix domain sockets to try to connect to before falling
    # back to a TCP connection.  A default redis server configuration
    # does not have unix domain sucket support enabled.
    UNIX_SOCKETS = ["/tmp/redis.sock",
                    "/var/run/redis.sock",
                    "/var/run/redis/redis.sock"]

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
      redis_db = ENV['LIVERESOURCE_DB'] || DEFAULT_REDIS_DB

      # Prefer a UNIX domain socket.  Fallback to a TCP connection.
      # If a Redis host parameter is ever supported, unix sockets should
      # only be tried if the redis server is running on the same system
      # as this client.
      @@proto_redis ||= nil
      if @@proto_redis.nil?
        redis = nil
        UNIX_SOCKETS.each do |redis_path|
          if File.exists?(redis_path)
            redis = Redis.new(:db => redis_db, :path => redis_path)
            begin
              # Simply instantiating the Redis object is not enough to know
              # whether or not the given UNIX socket is valid and can be used.
              redis.ping
            rescue Errno::EACCES, Errno::ENOENT, Errno::ENOTSOCK
              redis = nil
            end
          end
        end
        redis ||= Redis.new(:db => redis_db)
        @@proto_redis ||= redis
      end

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
      tag_errors(LiveResource::RedisError) do
        debug ">>", method.to_s, *params
        response = self.class.redis.send(method, *params, &block)
        debug "<<", response
        response
      end
    end

    def is_class?
      @redis_class == "class"
    end
  end
end
