require_relative 'resource_proxy'

module LiveResource
  module Finders

    def LiveResource.all(resource_class)
      redis_names = RedisClient.new(resource_class, nil).all

      redis_names.map do |redis_name|
        ResourceProxy.new(RedisClient.redisized_key(resource_class), redis_name)
      end
    end

    def LiveResource.find(resource_class, resource_name = nil, &block)
      if resource_name.nil? and block.nil?
        # Find class resource instead of instance resource.
        resource_name = resource_class
        resource_class = "class"
      end

      if block.nil?
        block = lambda { |name| name == resource_name.to_s ? name.to_s : nil }
      end

      redis_name = RedisClient.new(resource_class, nil).all.find do |name|
        block.call(name)
      end

      if redis_name
        ResourceProxy.new(RedisClient.redisized_key(resource_class), redis_name)
      else
        nil
      end
    end

    def LiveResource.any(resource_class)
      resources = all(resource_class)

      resources[rand(resources.length)]
    end
  end
end

