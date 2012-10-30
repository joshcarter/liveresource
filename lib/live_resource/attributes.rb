module LiveResource
  module Attributes
    def redis
      @_redis ||= RedisClient.new(resource_class, resource_name)
    end

    def remote_attributes
      if self.is_a? Class
        []
      else
        self.class.remote_instance_attributes
      end
    end

    def remote_attribute_read(key, options = {})
      redis.attribute_read(key, options)
    end

    def remote_attribute_write(key, value, options = {})
      if (key.to_sym == self.class.resource_name_attr) and !self.is_a?(Class)
        @_redis = RedisClient.new(resource_class, value)
      end

      redis.attribute_write(key, value, options)
    end

    def remote_modify(*attributes, &block)
      invalid_attrs = attributes - redis.registered_attributes
      unless invalid_attrs.empty?
        raise ArgumentError.new("remote_modify: no such attribute(s) '#{invalid_attrs}'")
      end

      unless block
        raise ArgumentError.new("remote_modify requires a block")
      end

      # Optimistic locking implemented along the lines of:
      #   http://redis.io/topics/transactions
      loop do
        # Gather up the attributes and their new values
        mods = attributes.map do |a|
          # Watch/get the value
          redis.attribute_watch(a)
          v = redis.attribute_read(a, {})

          # Block modifies the value
          v = block.call(a, v)
          [a, v]
        end

        # Start the transaction
        redis.multi

        mods.each do |mod|
          # Set to new value; if ok, we're done.
          redis.attribute_write(mod[0], mod[1], {})
        end

        # Attempt to execute the transaction. Otherwise we'll loop and
        # try again with the new value.
        break if redis.exec
      end
    end
  end
end
