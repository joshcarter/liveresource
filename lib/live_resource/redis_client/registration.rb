module LiveResource
  class RedisClient
    def instances_key
      "#{@redis_class}.instances"
    end

    def register
      hincrby instances_key, @redis_name, 1
    end

    def unregister
      hincrby instances_key, @redis_name, -1
    end

    def all
      names = []

      hgetall(instances_key).each_pair do |i, count|
        names << i if (count.to_i > 0)
      end

      names
    end
  end
end
