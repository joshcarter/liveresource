module LiveResource
  module Finders

  def LiveResource.all(redis_class)
    instances = []

    redis.hgetall(redis_class).each_pair do |i, count|
      instances << i if (count.to_i > 0)
    end

    instances
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
