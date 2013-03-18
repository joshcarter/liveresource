require 'set'

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

    # Register a resource in LiveResource. This includes adding all the
    # available remote methods and attributes.  If a resource is already
    # registered, the methods and attributes will be synchronized with what
    # is currently in Redis.
    def register(resource, *instance_init_params)
      resource_remote_methods = resource.remote_methods
      resource_remote_attributes = resource.remote_attributes

      anything_set = false
      was_already_registered = registered?

      loop do
        watch remote_methods_key
        watch remote_attributes_key
        watch instance_params_key
        watch instances_key

        anything_set = false
        methods_changed = false
        attributes_changed = false

        # Called outside of 'multi' because we need to know 'registered_methods'
        # right now and not when 'exec' is called.
        if registered_methods.to_set != resource_remote_methods.to_set
          anything_set = true
          methods_changed = true
        end

        # Called outside of 'multi' because we need to know
        # 'registered_attributes' right now and not when 'exec' is called.
        if registered_attributes.to_set != resource_remote_attributes.to_set
          anything_set = true
          attributes_changed = true
        end

        multi

        # Register methods and attributes used by this resource class but
        # only if they've changed.
        register_methods resource.remote_methods if methods_changed
        register_attributes resource.remote_attributes if attributes_changed

        unless is_class?
          # Class resources don't have instance parameters.
          # Registered resource instances will have already had their
          # instance parameters set when initially created and it is not
          # appropriate to change that.
          was_set = setnx instance_params_key, serialize(*instance_init_params)
          anything_set = true if was_set
        end

        was_set = hsetnx instances_key, @redis_name, 0
        anything_set = true if was_set

        # exec is ran even if 'anything_set' is false (i.e. nothing was to
        # be executed) to protect against the situation where a watched key
        # has changed on us (in which case we might need to actually run
        # a command).
        break if exec
      end

      if anything_set
        event = was_already_registered ? "updated" : "created"
        publish_event(event)
      end
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
