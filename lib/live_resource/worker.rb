class LiveResource
  class Worker
    EXIT_TOKEN = 'exit'
    
    def initialize(resource)
      @resource = resource
      @name = resource.name
      @redis = resource.redis
      @actions = resource.actions
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
      
      loop do
        @redis.del "#{@name}.action_in_progress"

        token = @redis.brpoplpush "#{@name}.actions", "#{@name}.action_in_progress", 0
        trace "Worker thread popped token #{token}"
        
        break if token == EXIT_TOKEN

        method = hget token, :method
        params = hget token, :params
        
        if !@actions.has_key?(method)
          set_result token, NoMethodError.new("undefined method `#{method}' for worker")
          next
        end
          
        proc = @actions[method]

        if (proc.arity != 0 && params.nil?)
          set_result token, ArgumentError.new("wrong number of arguments to `#{method}' (0 for #{proc.arity})")
          next
        end
        
        # Weirdness here: Ruby 1.8 appears to give a proc's arity() as -1
        # in some cases where the proc really takes 0 parameters. In the
        # case where it's -1 and params.length == 0, let that pass, the
        # proc.call below will work.
        if ((proc.arity != params.length) && (params.length != 0 && proc.arity != -1))
          set_result token, ArgumentError.new("wrong number of arguments to `#{method}' (#{params.length} for #{proc.arity})")
          next
        end
          
        begin
          set_result token, proc.call(*params)
        rescue Exception => e
          set_result token, e
        end
      end
      
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
    
    private
  
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
