require File.join(File.dirname(__FILE__), 'common')

module LiveResource
  module MethodSender
    include LiveResource::Common

    def remote_send(method, *params)
      wait_for_done remote_send_async(method, *params)
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

    def wait_for_done(token)
      result = redis_space.result_get(token)

      redis_space.method_delete token

      if result.is_a?(Exception)
        raise result
      else
        result
      end
    end

    def done_with?(token)
      # Token follows the sequence:
      #   wait list -> in progress list -> result
      # Check result first, since the method provider sets the result 
      # before removing the token from the in-progress list. Check wait
      # list followed by in-progress list, since the provider will do an
      # atomic move from wait to in-progress, which could happen right
      # between our checks.
      #
      # FIXME: there's still a race in here; if we're really slow, the
      # method provider could move from wait list all the wait to result
      # between us checking result_exists? and checking the wait list.
      if redis_space.result_exists?(token)
        true
      elsif redis_space.method_tokens_waiting.include?(token)
        false
      elsif redis_space.method_tokens_in_progress.include?(token)
        false
      else
        raise ArgumentError.new("No method #{token} pending")
      end
    end
  end
end