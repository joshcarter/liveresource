require_relative 'log_helper'
require_relative 'redis_client'

module LiveResource
  # Returned from LiveResource finder methods (all, find, etc), acts as a
  # proxy to a remote resource.
  class ResourceProxy
    include LiveResource::LogHelper
    include LiveResource::HasRedisClient

    def initialize(redis_class, redis_name)
      @redis_class = redis_class
      @redis_name = redis_name
      @remote_methods =
        redis.lrange("class.#{redis_class}", 0, -1)
    end

    def redis_class
      @redis_class
    end

    def redis_name
      @redis_name
    end

    def method_missing(method, *params, &block)
      if @remote_methods.include?(method)
        # ...
      else
        super
      end
    end

    def respond_to?(method)
      return true if @remote_methods.include?(method)
      super
    end
  end
end
