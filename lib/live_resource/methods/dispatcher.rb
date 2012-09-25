require_relative '../log_helper'
require_relative '../redis_client'

module LiveResource
  class RemoteMethodDispatcher
    include LogHelper

    attr_reader :thread, :resource

    def initialize(resource)
      @resource = resource
      @thread = nil
      @running = false

      start
    end

    def redis
      @resource.redis
    end

    def start
      return if @thread

      @thread = Thread.new { run }
    end

    def stop
      return if @thread.nil?

      redis.method_push exit_token
      @running = false
      @thread.join
      @thread = nil
    end

    def running?
      (@thread != nil) && @running
    end

    def wait_for_running
      while !running? do
        Thread.pass
      end
    end

    def run
      info("#{self} method dispatcher starting")

      # Register methods and attributes used by this resource class
      redis.register_methods @resource.remote_methods
      redis.register_attributes @resource.remote_attributes

      # Need to register our class and instance in Redis so the finders
      # (all, any, etc.) will work.
      redis.register

      @running = true

      begin
        loop do
          token = redis.method_wait

          if is_exit_token(token)
            if token == exit_token
              redis.method_done token
              break
            else
              redis.method_push token
              next
            end
          end

          method = redis.method_get(token)

          begin
            result = validate_method(method).call(*method.params)

            if result.is_a? Resource
              # Return descriptor of a resource proxy instead
              result = ResourceProxy.new(
                result.redis.redis_class,
                result.redis.redis_name)
            elsif result.is_a? RemoteMethodForward
              # Append forwarding instructions to current method
              method.forward_to result
            end

            if method.final_destination?
              redis.method_result method, result
            else
              # Forward on to next step in method's path
              dest = method.next_destination!

              unless result.is_a? RemoteMethodForward
                # First parameter(s) to next method will be the result
                # of this method call.
                if result.is_a? Array
                  method.params = result + method.params
                else
                  method.params.unshift result
                end
              end

              dest.remote_send method
            end
          rescue Exception => e
            # TODO: custom encoding for exception to make it less
            # Ruby-specific.

            debug "Method #{method.token} failed:", e.message
            redis.method_result method, e
          end

          redis.method_done token
          redis.method_discard_result(token) if method.flags[:discard_result]
        end
      ensure
        # NOTE: if this process crashes outright, or we lose network
        # connection to Redis, or whatever -- this decrement won't occur.
        # Supervisor should clean up where possible.
        redis.unregister

        info("#{self} method dispatcher exiting")

      end
    end

    private

    # Verify validity of remote method being called
    def validate_method(m)

      # Check that method is remote callable
      unless @resource.remote_methods.include?(m.method)
        raise NoMethodError.new("Undefined method `#{m.method}' (#{@resource.remote_methods.join(', ')})")
      end

      method = @resource.method(m.method)

      # Check for nil params when method is expecting 1 or more arguments
      if (method.arity != 0 && m.params.nil?)
        raise ArgumentError.new("wrong number of arguments to `#{m.method}'" \
                      "(0 for #{method.arity})")
      end

      # If the arity is >= 0, then the number of params should be the same as the
      # arity.
      #
      # For variable argument methods, the arity is -n-1 where n is the number of
      # required arguments. This means if the arity is < -1, there must be at least
      # (artiy.abs - 1) arguments (NOTE: if there are no required arguments, there's
      # nothing to check).
      if (method.arity >= 0 and method.arity != m.params.length) or
          (method.arity < -1 and (method.arity.abs - 1) > m.params.length)
        raise ArgumentError.new("wrong number of arguments to `#{m.method}'" \
                      "(#{m.params.length} for #{method.arity})")
      end

      method
    end

    EXIT_PREFIX = 'exit'

    def exit_token
      # Construct an exit token for this resource
      "#{EXIT_PREFIX}.#{Socket.gethostname}.#{Process.pid}.#{@thread.object_id}"
    end

    def is_exit_token(token)
      # Exit tokens are strings which can be search with a regular expresion.
      return false unless token.respond_to? :match
      token.match /^#{EXIT_PREFIX}/
    end
  end
end
