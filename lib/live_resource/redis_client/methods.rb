require 'yaml'

module LiveResource
  class RedisClient
    def remote_methods_key
      "#{@redis_class}.methods"
    end

    def methods_list
      "#{@redis_class}.#{@redis_name}.methods_pending"
    end

    def methods_in_progress_list
      "#{@redis_class}.#{@redis_name}.methods_in_progress"
    end

    def method_details(token)
      "#{@redis_class}.#{@redis_name}.method.#{token}"
    end

    def result_details(token)
      "#{@redis_class}.#{@redis_name}.result.#{token}"
    end

    def register_methods(methods)
      sadd remote_methods_key, methods
    end

    def registered_methods
      methods = smembers remote_methods_key

      methods.map { |m| m.to_sym }
    end

    def method_wait
      brpoplpush methods_list, methods_in_progress_list, 0
    end

    def method_push(token)
      lpush methods_list, token
    end

    def method_done(token)
      lrem methods_in_progress_list, 0, token
    end

    def method_send(method, params, flags = {})
      # Choose unique token for this action; retry if token is already in
      # use by another action.
      token = nil

      loop do
        token = sprintf("%05d", Kernel.rand(100000))
        break if hsetnx(method_details(token), :method, method)
      end

      hset method_details(token), :params, serialize(params)
      hset method_details(token), :flags, serialize(flags)
      method_push token
      token
    end

    def method_get(token)
      method = hget method_details(token), :method
      params = hget method_details(token), :params
      flags = hget method_details(token), :flags

      [method.to_sym, deserialize(params), deserialize(flags)]
    end

    def method_result(token, result)
      # Need to watch the method while setting the result; if the caller 
      # has given up waiting before we set the result, we don't want to
      # leave extra crud in Redis.

      watch method_details(token)

      unless exists(method_details(token))
        # Caller must have deleted method
        warn "setting result for method #{token}, but caller deleted it"
        unwatch
        return
      end

      begin
        multi
        lpush result_details(token), serialize(result)
        exec
      rescue RuntimeError => e
        # Must have been deleted while we were working on it, bail out.
        warn e
        discard
      end
    end

    def method_wait_for_result(token, timeout)
      result = nil

      begin
        list, result = brpop result_details(token), timeout

        if result.nil?
          raise RuntimeError.new("timed out waiting for method #{token}")
        end

        result = deserialize(result)
      rescue
        # Clean token from any lists before passing up exception
        method_cleanup(token)
        raise
      ensure
        # Clear out original method call details
        del method_details(token)
      end
    end

    def method_discard_result(token)
      del result_details(token)
      del method_details(token)
    end

    def method_done_with?(token)
      token = token.to_s

      # Need to do a multi/exec so we can atomically look in 3 lists
      # for the token
      multi
      lrange methods_list, 0, -1
      lrange methods_in_progress_list, 0, -1
      lrange result_details(token), 0, -1
      result = exec

      if (result[2] != [])
        # Result already pending
        true
      elsif result[0].include?(token) or result[1].include?(token)
        # Still in methods or methods-in-progress
        false
      else
        raise ArgumentError.new("No method #{token} pending")
      end
    end

    private

    def method_cleanup(token)
      token = token.to_s

      # Need to do a multi/exec so we can atomically delete from all 3 lists
      multi
      lrem methods_list, 0, token
      lrem methods_in_progress_list, 0, token
      lrem result_details(token), 0, token
      exec
    end

    def serialize(value)
      if value.is_a? Exception
        # YAML can't dump an exception properly, it loses the message.
        # and the backtrace.  Save those separately as strings.
        YAML::dump [value, value.message, value.backtrace]
      else
        YAML::dump value
      end
    end

    def deserialize(value)
      raise "Cannot deserialize nil value" if value.nil?

      result = YAML::load(value)

      if result.is_a?(Array) and result[0].is_a?(Exception)
        # Inverse of what serialize() is doing with exceptions.
        e = result[0].class.new(result[1])
        e.set_backtrace result[2]
        result = e
      end

      result
    end
  end
end
