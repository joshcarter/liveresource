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
      begin
        result = redis_space.result_get(token, timeout)
      rescue
        # Clean token from any lists before passing up exception
        redis_space.delete_token token
        raise
      ensure
        redis_space.method_delete token
      end

      if result.is_a?(Exception)
        # Merge the backtrace from the passed exception with this
        # stack trace so the final backtrace looks like the method_sender
        # called the method_provider directly.
        trace = merge_backtrace caller, result.backtrace
        result.set_backtrace trace
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

  private

    # Merge the stack trace from the method sendor and method
    # provider so it looks like one, seamless stack trace.
    # LiveResource traces are removed and replaced with a simple
    # 'via LiveResource' type message.
    def merge_backtrace(sender_trace, provider_trace)
      return nil if provider_trace.nil?
      return provider_trace if sender_trace.nil?

      # Find the first live resource stack trace
      index = provider_trace.index do |t|
        t =~ /lib\/live_resource\/method_provider/
      end

      # Slice off everything starting at that index
      merged_trace = provider_trace[0 .. (index - 1)]

      # Add a trace that indicates that live resource was used
      # to link the sender to the provider.
      merged_trace << 'via LiveResource'

      # For the sender trace, remove the 'method_sender'
      # part of the trace.  If a method_sender trace wasn't found,
      # attach the entire sender_trace to the merged trace.
      index = sender_trace.index do |t| 
        t =~ /lib\/live_resource\/method_sender/
      end
      index ||= -1

      merged_trace + sender_trace[(index + 1) .. (sender_trace.length - 1)]
    end
  end
end
