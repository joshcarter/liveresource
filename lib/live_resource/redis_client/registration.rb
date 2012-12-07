module LiveResource
  class RedisClient
    # A hash of instances.
    # Hash name is the class_name.instances (note there's one hash for all class resources).
    # Keys are instances names.
    # Values are counts (this is the total number of instances of that type in the cluster).
    def instances_key(redis_class=nil)
      redis_class = redis_class.nil? ? @redis_class : RedisClient.redisized_key(redis_class)
      "#{redis_class}.instances"
    end

    def instance_params_key(redis_class=nil, redis_name=nil)
      redis_class = redis_class.nil? ? @redis_class : RedisClient.redisized_key(redis_class)
      redis_name = redis_name.nil? ? @redis_name : RedisClient.redisized_key(redis_name)

      "#{redis_class}.#{redis_name}.instance_params"
    end

    # Register an instance in LiveResource. This includes
    # adding all the available remote methods and attributes.
    def register(resource, *instance_init_params)
      loop do
        watch remote_methods_key
        watch remote_attributes_key
        watch instance_params_key
        watch instances_key

        multi

        # Register methods and attributes used by this resource class
        register_methods resource.remote_methods
        register_attributes resource.remote_attributes

        unless is_class?
          # Class resources don't have instance parameters.
          set instance_params_key, serialize(*instance_init_params)
        end

        hsetnx instances_key, @redis_name, 0
        break if exec
      end
      publish_event("created")
    end

    def registered?
      hexists instances_key, @redis_name
    end

    # TODO: "unregister" an instance, removing all its state from redis.
    
    def start_instance
      hincrby instances_key, @redis_name, 1
      publish_event("started")
    end

    def stop_instance
      hincrby instances_key, @redis_name, -1
      publish_event("stopped")
    end

    def all
      names = []

      hgetall(instances_key).each_pair do |i, count|
        names << i if (count.to_i > 0)
      end

      names
    end

    # Get all the instances of a given class
    def registered_instances
      names = []

      if is_class?
        key = instances_key(@redis_name)
      else
        key = instances_key
      end

      instances = hgetall(key)

      unless instances.nil?
        instances.each_key do |k|
          names << k
        end
      end

      names
    end

    # Get the total number instances of this resource in the system.
    def num_instances
      return 0 unless registered?
      hget(instances_key, @redis_name).to_i
    end

    # Get the initialization params used for this instance.
    # NOTE: class resources don't have init params.
    def instance_params(redis_class=nil, redis_name=nil)
        deserialize(get instance_params_key(redis_class, redis_name))
    end

    def instance_channel
      if is_class?
        # Class resource
        "#{@redis_name}.instances"
      else
        "#{@redis_class}.instances"
      end
    end

    private

    def publish_event(type)
      # TODO: better messages, probably as an object or at least a hash
      publish instance_channel, "#{@redis_class}.#{@redis_name}.#{type}"
    end
  end
end
