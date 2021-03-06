require 'yaml'

module LiveResource
  class RedisClient
    def remote_methods_key
      if is_class?
        "#{@redis_name}.class_methods"
      else
        "#{@redis_class}.methods"
      end
    end

    def methods_list
      "#{@redis_class}.#{@redis_name}.methods_pending"
    end

    def methods_in_progress_list
      "#{@redis_class}.#{@redis_name}.methods_in_progress"
    end

    def method_details(token)
      "#{token.redis_class}.#{token.redis_name}.method.#{token.seq}"
    end

    def result_details(token)
      "#{token.redis_class}.#{token.redis_name}.result.#{token.seq}"
    end

    # Synchronize the given methods with what is currently registered in
    # Redis under the {remote_methods_key} key.  If the key does not exist,
    # the methods will simply be added.
    #
    # This method is meant to be called from a Redis transaction since
    # more than one command is executed.  Because of that, this method cannot
    # compare the given methods against what is currently in Redis.
    def register_methods(methods)
      del remote_methods_key

      # sadd raises an exception when passing an empty array.  Plus,
      # there's no sense in running an unnecessary Redis command.
      unless methods.empty?
        sadd remote_methods_key, methods
      end
    end

    def registered_methods
      methods = smembers remote_methods_key

      methods.map { |m| m.to_sym }
    end

    # This method is meant to be called from a Redis transaction since
    # more than one command is executed.  Because of that, this method cannot
    # compare the given methods against what is currently in Redis.
    def unregister_methods
      del methods_list
      del methods_in_progress_list
      del remote_methods_key
    end

    def method_wait
      token = brpoplpush methods_list, methods_in_progress_list, 0
      deserialize(token)
    end

    def method_push(token)
      lpush methods_list, serialize(token)
    end

    def method_done(token)
      lrem methods_in_progress_list, 0, serialize(token)
    end

    def method_get(token)
      method = get method_details(token)

      deserialize(method)
    end

    def method_send(method)
      unless method.token
        # Choose unique token for this action; retry if token is already in
        # use by another action.
        loop do
          method.token = RemoteMethodToken.new(
                                           @redis_class,
                                           @redis_name,
                                           sprintf("%05d", Kernel.rand(100000)))

          break if setnx(method_details(method.token), serialize(method))
        end
      else
        # Re-serialize current state of method to existing location.
        set method_details(method.token), serialize(method)
      end

      method_push method.token
      method
    end

    def method_result(method, result)
      token = method.token

      # Need to watch the method while setting the result; if the caller
      # has given up waiting before we set the result, we don't want to
      # leave extra crud in Redis.
      watch method_details(token)

      unless exists(method_details(token))
        # Caller must have deleted method
        warn "setting result for method #{method.method} (#{token}), "\
             "but caller deleted it (caller likely gave up waiting).  "\
             "Result was: #{result}"
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

    def method_wait_for_result(method, timeout)
      token = method.token
      result = nil
      list = nil

      begin
        list, result = brpop result_details(token), timeout

        if result.nil?
          raise RuntimeError.new(
            "timed out after #{timeout} seconds waiting for method #{method.method} (#{token})")
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

    def method_done_with?(method)
      st = serialize(method.token)

      # Need to do a multi/exec so we can atomically look in 3 lists
      # for the token
      multi
      lrange methods_list, 0, -1
      lrange methods_in_progress_list, 0, -1
      lrange result_details(method.token), 0, -1
      result = exec

      if (result[2] != [])
        # Result already pending
        true
      elsif result[0].include?(st) or result[1].include?(st)
        # Still in methods or methods-in-progress
        false
      else
        raise ArgumentError.new("No method #{token} pending")
      end
    end

    private

    def method_cleanup(token)
      st = serialize(token)

      # Need to do a multi/exec so we can atomically delete from all 3 lists
      multi
      lrem methods_list, 0, st
      lrem methods_in_progress_list, 0, st
      lrem result_details(token), 0, st
      exec
    end

    def serialize(value)
      if value.is_a? Exception
        # YAML can't (un)parse an exception properly.  It looses the backtrace
        # and can sometimes cause errors trying to unparse a YAML'ized
        # version of the excepion object itself.
        #
        # Save those separately as strings in such a way that the other end
        # knows we're manually sending an exception over.
        YAML::dump ['Exception', value.class.name, value.message, value.backtrace]
      else
        YAML::dump value
      end
    end

    def deserialize(value)
      return nil if value.nil?

      result = YAML::load(value)

      if result.is_a?(Array) and result[0] == 'Exception' and result.length == 4
        # Inverse of what serialize() is doing with exceptions.
        exception_class = get_exception(result[1])
        e = exception_class.new(result[2]) 
        e.set_backtrace result[3]
        result = e
      end

      result
    end

    # Get the exception class that matches the given string, while taking
    # into account exceptions that are namespaced.
    def get_exception(exception_string)
      unless exception_string.is_a?(String)
        raise(ArgumentError, 'exception_string is not a string')
      end

      exception_string.split('::').inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end
  end
end
