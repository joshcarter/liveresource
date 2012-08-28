module LiveResource
  class RedisClient
    def remote_attributes_key
      if @redis_class == "class"
        "#{@redis_name}.class_attributes"
      else
        "#{@redis_class}.attributes"
      end
    end

    def register_attributes(attributes)
      unless attributes.empty?
        sadd remote_attributes_key, attributes
      end
    end

    def registered_attributes
      attributes = smembers remote_attributes_key

      attributes.map { |a| a.to_sym }
    end

    def attribute_read(key, options)
      get "#{@redis_class}.#{@redis_name}.attributes.#{key}"
    end

    def attribute_write(key, value, options)
      set "#{@redis_class}.#{@redis_name}.attributes.#{key}", value
    end
  end
end
