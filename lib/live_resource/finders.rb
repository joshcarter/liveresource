module LiveResource
  module Finders

    def LiveResource.all(resource_class)
      # FIXME: need to create ResourceProxy objects
      RedisClient.new(resource_class, nil).all
    end

    def LiveResource.find(resource_class, resource_name = nil, &block)
      if resource_name.nil? and block.nil?
        raise(ArgumentError, "must provide either name or matcher block")
      end

      if block.nil?
        block = lambda { |name| name == resource_name.to_s ? name.to_s : nil }
      end

      RedisClient.new(resource_class, nil).all.each do |name|
        found = block.call(name)

        # FIXME: create ResourceProxy object here
        return found if found
      end

      nil
    end
  end
end

