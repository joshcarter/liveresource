module LiveResource
  class RedisClient
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
  end
end
