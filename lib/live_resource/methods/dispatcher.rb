require_relative '../log_helper'
require_relative '../redis_client'

module LiveResource
  class RemoteMethodDispatcher
    include LogHelper

    attr_reader :thread, :resource
    EXIT_TOKEN = 'exit'

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

      redis.method_push EXIT_TOKEN
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

          if token == EXIT_TOKEN
            redis.method_done token
            break
          end

          method = redis.method_get(token)

          begin
            puts "method: #{method.to_yaml}"

            m = validate_method method

            result = m.call(*method.params)

            if result.is_a? Resource
              # Return descriptor of a resource proxy instead
              result = ResourceProxy.new(
                result.redis.redis_class,
                result.redis.redis_name)
            end

            if method.final_destination?
              redis.method_result method, result
            else
              # Forward on to next step in method's path
              dest = method.next_destination!

              # First parameter(s) to next method will be the result
              # of this method call.
              if result.is_a? Array
                method.params = result + method.params
              else
                method.params.unshift result
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
      unless @resource.remote_methods.include?(m.method)
        raise NoMethodError.new("Undefined method `#{m.method}' (#{@resource.remote_methods.join(', ')})")
      end

      method = @resource.method(m.method)

      if (method.arity != 0 && m.params.nil?)
        raise ArgumentError.new("wrong number of arguments to `#{m.method}'" \
                      "(0 for #{method.arity})")
      end

      if (method.arity > 0 and method.arity != m.params.length) or
          (method.arity < 0 and method.arity.abs != m.params.length and
          (method.arity.abs - 1) != m.params.length)
        raise ArgumentError.new("wrong number of arguments to `#{m.method}'" \
                      "(#{m.params.length} for #{method.arity})")
      end

      method
    end
  end
end
