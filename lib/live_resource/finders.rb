module LiveResource
  module Finders

  def LiveResource.all(redis_class)
    instances = []

    redis.hgetall(redis_class.to_s).each_pair do |i, count|
      instances << i if (count.to_i > 0)
    end

    # FIXME: need to create clients here
    instances
  end

  # TODO: if block provided, need to iterate over all and let
  # block decide what to do.
  def LiveResource.find(redis_class, redis_instance)
    count = redis.hget(redis_class.to_s, redis_instance.to_s)

    # FIXME: create instance here
    (count && count.to_i > 0) ? redis_instance : nil
  end


  #   
  # def self.each(type, &block)
  #   
  # end
  # 
  # def self.find(type, name = nil, &block)
  #   if name.nil? and block.nil?
  #     raise(ArgumentError, "must provide either name or matcher block")
  #   end
  # 
  #   if block.nil?
  #     block = lamda { |i| i.name == name ? i : nil }
  #   end
  # 
  #   each(type) do |instance|
  #     found = block.call(instance)
  #     return found if found
  #   end
  # end
    


  end
end
