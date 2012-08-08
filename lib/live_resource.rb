require File.join(File.dirname(__FILE__), 'live_resource', 'log_helper')
require File.join(File.dirname(__FILE__), 'live_resource', 'redis_space')
require File.join(File.dirname(__FILE__), 'live_resource', 'attribute')
require File.join(File.dirname(__FILE__), 'live_resource', 'subscriber')
require File.join(File.dirname(__FILE__), 'live_resource', 'method_provider')
require File.join(File.dirname(__FILE__), 'live_resource', 'method_sender')

module LiveResource
  
  def self.all(type)
    
    
  end
    
  def self.each(type, &block)
    
  end
  
  def self.find(type, name = nil, &block)
    if name.nil? and block.nil?
      raise(ArgumentError, "must provide either name or matcher block")
    end

    if block.nil?
      block = lamda { |i| i.name == name ? i : nil }
    end
  
    each(type) do |instance|
      found = block.call(instance)
      return found if found
    end
  end
  
  def register(obj)
    redis_name, redis_class = redis_name_and_class(obj)
    redis.lpush redis_class, redis_name
  end
  
  def unregister(obj)
    redis_name, redis_class = redis_name_and_class(obj)
    redis.lrem redis_class, 0, redis_name    
  end
  

end