require File.join(File.dirname(__FILE__), 'common')

module LiveResource
  module MethodSender
    include LiveResource::Common

    def remote_send(method, *params)
      wait_for_done remote_send_async(method, *params)
    end

    def remote_send_with_timeout(method, timeout, *params)
      token = remote_send_async(method, *params)
      wait_for_done(token, timeout)      
    end

    def remote_send_async(method, *params)
      # Choose unique token for this action; retry if token is already in
      # use by another action.
      token = nil
      loop do
        token = sprintf("%05d", Kernel.rand(100000))
        break if redis_space.method_set_exclusive(token, :method, method)
      end

      redis_space.method_set token, :params, params
      redis_space.method_push token
      token
    end

    def wait_for_done(token, timeout = 0)
      result = redis_space.result_get(token, timeout)

      redis_space.method_delete token

      if result.is_a?(Exception)
        raise result
      else
        result
      end
    end

    def done_with?(token)
      # Token follows the sequence:
      #   :methods list -> :methods_in_progress -> :results
      # Need to look at all in one atomic action.
      location = redis_space.find_token(token)
      
      if (location == :results)
        true
      elsif (location == :methods) || (location == :methods_in_progress)
        false
      else
        raise ArgumentError.new("No method #{token} pending")
      end
    end
  end
end