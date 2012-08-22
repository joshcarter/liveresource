module LiveResource
  class RedisClient
    def remote_methods_key
      "#{@redis_class}.methods"
    end

    def methods_list
      "#{@redis_class}.#{@redis_name}.methods_pending"
    end

    def methods_in_progress_list
      "#{@redis_class}.#{@redis_name}.methods_in_progress"
    end

    def register_methods(methods)
      sadd remote_methods_key, methods
    end

    def registered_methods
      methods = smembers remote_methods_key

      methods.map { |m| m.to_sym }
    end

    def method_wait
      brpoplpush methods_list, methods_in_progress_list, 0
    end

    def method_push(token)
      lpush methods_list, token
    end

    def method_done(token)
      lrem methods_in_progress_list, 0, token
    end
  end
end
