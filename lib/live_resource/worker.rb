class LiveResource
  class Worker
    EXIT_TOKEN = 'exit'
    
    def initialize(resource)
      @resource = resource
      @name = resource.name
      @redis = resource.redis
      @thread = Thread.new { self.main }
    end

    # List of pending actions, new action tokens pushed on the left side:
    #   [ 1236, 1235, 1234 ]
    # Take one off the right side (blocking operation), reference the
    # token for it of the form:
    #   name.actions.1234.method => YAML-ized method
    #   name.actions.1234.params => YAML-ized parameters
    
    def main
      trace "Worker thread starting"
      event_hooks(:start)
      
      loop do
        @redis.del "#{@name}.action_in_progress"

        token = @redis.brpoplpush "#{@name}.actions", "#{@name}.action_in_progress", 0
        trace "Worker thread popped token #{token}"
        
        break if token == EXIT_TOKEN

        method_name = hget token, :method
        params = hget token, :params
        
        method_symbol = self.class.instance_eval do
          @event_hooks[:remote_method] &&
          @event_hooks[:remote_method].find { |m| m == method_name }
        end

        if method_symbol.nil?
          set_result token, NoMethodError.new("undefined method `#{method_name}' for worker")
          next
        end
        
        method = method(method_symbol)
        
        if (method.arity != 0 && params.nil?)
          set_result token, ArgumentError.new("wrong number of arguments to `#{method_name}' (0 for #{method.arity})")
          next
        end
        
        if (method.arity != params.length)
          set_result token, ArgumentError.new("wrong number of arguments to `#{method_name}' (#{params.length} for #{method.arity})")
          next
        end
          
        begin
          set_result token, method.call(*params)
        rescue Exception => e
          set_result token, e
        end
      end
      
      event_hooks(:stop)
      @redis.del "#{@name}.action_in_progress"
      trace "Worker thread exiting"
    end
    
    def stop
      # Create new Redis instance; if the stopping resource is the same
      # instance as the worker, sharing the Redis connection would
      # deadlock because it's already blocked in the brpop() above.
      Redis.new.lpush "#{@name}.actions", EXIT_TOKEN
      @thread.join
    end
    
    singleton_class = class << self; self; end

    # Create event hook methods like on_start, on_stop, etc..
    singleton_class.class_eval do
      [:on_start, :on_stop, :remote_method].each do |event|
        define_method(event) do |*method_names|
          @event_hooks ||= Hash.new
          @event_hooks[event] ||= []
          @event_hooks[event] += method_names
        end
      end
    end
    
  private
  
    def event_hooks(event)
      instance = self # Instance needed below

      self.class.instance_eval do
        methods = @event_hooks[event]

        return if methods.nil?

        methods.each { |m| instance.send(m) }
      end
    end
  
    def hash_for(token)
      "#{@name}.actions.#{token}"
    end
    
    def hsetnx(token, key, value)
      trace("hsetnx #{hash_for(token)} #{key}: #{value}")
      @redis.hsetnx(hash_for(token), key, YAML::dump(value))
    end
    
    def hset(token, key, value)
      trace("hset #{hash_for(token)} #{key}: #{value}")
      @redis.hset(hash_for(token), key, YAML::dump(value))
    end
    
    def hget(token, key)
      trace("hget #{hash_for(token)} #{key}")
      value = @redis.hget(hash_for(token), key)
      trace(" -> #{value}")
      YAML::load(value)
    end
    
    def set_result(token, result)
      trace(" result -> #{result}")
      if result.is_a? Exception
        # YAML can't dump an exception properly, it loses the message 
        # and stack trace. Save those separately.
        @redis.lpush "#{@name}.results.#{token}", YAML::dump([result, result.message])
      else
        @redis.lpush "#{@name}.results.#{token}", YAML::dump(result)
      end
    end

    def trace(s)
      @resource.trace(s)
    end
  end # class Worker
end # class LiveResource
