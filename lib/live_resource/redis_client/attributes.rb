module LiveResource
  class RedisClient
    def remote_attributes_key
      if is_class?
        "#{@redis_name}.class_attributes"
      else
        "#{@redis_class}.attributes"
      end
    end

    # Synchronize the given attributes with what is currently registered in
    # Redis under the {remote_attributes_key} key.  If the key does not exist,
    # the attributs will simply be added.
    #
    # This method is meant to be called from a Redis transaction since
    # more than one command is executed.  Because of that, this method cannot
    # compare the given attributes against what is currently in Redis.
    def register_attributes(attributes)
      del remote_attributes_key

      # sadd raises an exception when passing an empty array.  Plus,
      # there's no sense in running an unnecessary Redis command.
      unless attributes.empty?
        sadd remote_attributes_key, attributes
      end
    end

    def registered_attributes
      attributes = smembers remote_attributes_key

      attributes.map { |a| a.to_sym }
    end

    def unregister_attribute(key)
      del "#{@redis_class}.#{redis_name}.attributes.#{key}"
    end

    # This method is meant to be called from a Redis transaction since
    # more than one command is executed.  Because of that, this method cannot
    # compare the given attributes against what is currently in Redis.
    def unregister_attributes(attributes)
      attributes.each do |key|
        unregister_attribute key
      end
      del remote_attributes_key
    end

    def attribute_read(key, options={})
      deserialize(get("#{@redis_class}.#{@redis_name}.attributes.#{key}"))
    end

    def attribute_write(key, value, options={})
      redis_key = "#{@redis_class}.#{@redis_name}.attributes.#{key}"
      if options[:no_overwrite]
        setnx(redis_key, serialize(value))
      else
        set(redis_key, serialize(value))
      end
    end

    def attribute_watch(key)
      watch("#{@redis_class}.#{redis_name}.attributes.#{key}")
    end 
  end
end
