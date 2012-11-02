module LiveResource
  class RedisClient
    def instances_key
      "#{@redis_class}.instances"
    end

    def register(instance_init_params)
      loop do
        watch instance_params_key
        watch instance_host_key
        watch instances_key
        multi

        unless is_class?
          # Class resources don't have instance parameters.
          set instance_params_key, serialize(instance_init_params)
        end

        sadd instance_host_key, Process.pid
        hincrby instances_key, @redis_name, 1
        publish_event("started")
        break if exec
      end
    end

    def unregister
      loop do
        watch instance_host_key
        watch instances_key
        multi
        srem instance_host_key, Process.pid
        hincrby instances_key, @redis_name, -1
        publish_event("stopped")
        break if exec
      end
    end

    def all
      names = []

      hgetall(instances_key).each_pair do |i, count|
        names << i if (count.to_i > 0)
      end

      names
    end

    # Get the total number instances of this resource in the system.
    def num_instances
      hget(instances_key, @redis_name).to_i
    end

    # Get the initialization params used for this instance.
    # NOTE: class resources don't have init params.
    def instance_params
      if is_class?
        nil
      else
        deserialize(get instance_params_key)
      end
    end

    # Get the list of process ids where this resource is running instances
    # on the localhost.
    def local_instance_pids
      smembers instance_host_key
    end

    # Is this host running a local instance?
    def local_instances?
      scard(instance_host_key) > 0
    end

    # Check if the given pid is running an instance of this resource.
    def pid_has_instance?(pid)
      sismember instance_host_key, pid
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

    def is_class?
      @redis_class == "class"
    end

    # A hash of instances.
    # Hash name is the class_name.instances (note there's one hash for all class resources).
    # Keys are instances names.
    # Values are counts (this is the total number of instances of that type in the cluster).
    def instances_key
      "#{@redis_class}.instances"
    end

    def instance_params_key
      "#{@redis_class}.#{@redis_name}.instance_params"
    end

    def instance_host_key
      "#{@redis_class}.#{@redis_name}.instances.#{Socket.gethostname}"
    end

    def instances_pids_key
      "#{instances_key}.pids"
    end

    def instance_pid
      "#{Socket.gethostname}.#{Process.pid}"
    end

    def publish_event(type)
      publish instance_channel, "#{@redis_class}.#{@redis_name}.#{type}"
    end
  end
end
