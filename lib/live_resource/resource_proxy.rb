require_relative 'log_helper'
require_relative 'redis_client'
require_relative 'future'

module LiveResource
  # Returned from LiveResource finder methods (all, find, etc), acts as a
  # proxy to a remote resource.
  class ResourceProxy
    include LiveResource::LogHelper

    attr_reader :redis_class, :redis_name

    def initialize(redis_class, redis_name)
      @redis_class = redis_class
      @redis_name = redis_name
      @redis = RedisClient.new(redis_class, redis_name)
      @remote_methods = @redis.registered_methods
    end

    def redis_class
      @redis_class
    end

    def redis_name
      @redis_name
    end

    def method_missing(method, *params, &block)
      # Strip trailing ?, ! for seeing if we support method
      stripped_method = method.to_s.sub(/[!,?]$/, '').to_sym

      if @remote_methods.include?(stripped_method)
        if method.match(/!$/)
          # TODO: where do we clean up the method?
          raise ArgumentError.new("can't handle async/no-future methods yet")
        elsif method.match(/\?$/)
          # Async call with future
          token = remote_send_async stripped_method, params
          Future.new(self, token)
        else
          # Synchronous method call
          remote_send(method, params)
        end
      else
        super
      end
    end

    def respond_to_missing?(method, include_private)
      stripped_method = method.to_s.sub(/[!,?]$/, '').to_sym

      @remote_methods.include?(stripped_method)
    end

    def remote_send(method, *params)
      wait_for_done remote_send_async(method, *params)
    end

    def remote_send_with_timeout(method, timeout, *params)
      token = remote_send_async(method, *params)
      wait_for_done(token, timeout)
    end

    def remote_send_async(method, *params)
      @redis.method_send(method, params)
    end

    def wait_for_done(token, timeout = 0)
      result = @redis.method_wait_for_result(token, timeout)

      if result.is_a?(Exception)
        # Merge the backtrace from the passed exception with this
        # stack trace so the final backtrace looks like the method_sender
        # called the method_provider directly.
        # trace = merge_backtrace caller, result.backtrace
        # result.set_backtrace trace

        result.set_backtrace result.backtrace
        raise result
      else
        result
      end
    end

    def done_with?(token)
      @redis.method_done_with? token
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
        t =~ /lib\/live_resource\/method_provider/  ## FIXME
      end

      # Slice off everything starting at that index
      result = provider_trace[0 .. (index - 1)]

      # Add a trace that indicates that live resource was used
      # to link the sender to the provider.
      result << 'via LiveResource'

      # For the sender trace, remove the 'method_sendor'
      # part of the trace.
      index = sender_trace.index do |t| 
        t =~ /lib\/live_resource\/method_sender/   ## FIXME
      end
      result += sender_trace[(index + 1) .. (sender_trace.length - 1)]

      result
    end
  end
end