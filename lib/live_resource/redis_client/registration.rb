module LiveResource
  class RedisClient
    def register(resource)
      hincrby resource.redis_class, resource.redis_name, 1
    end

    def unregister(resource)
      hincrby resource.redis_class, resource.redis_name, -1
    end
  end
end
