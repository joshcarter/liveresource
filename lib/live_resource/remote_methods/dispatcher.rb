require_relative '../log_helper'
require_relative '../redis_client'

module LiveResource
  class RemoteMethodDispatcher
    include LogHelper

    attr_reader :thread, :resource, :redis
    EXIT_TOKEN = 'exit'

    def initialize(resource)
      @resource = resource
      @redis = RedisClient.new(@resource.resource_class, @resource.resource_name)
      @thread = nil
      @running = false

      start
    end

    def start
      return if @thread

      @thread = Thread.new { run }
    end

    def stop
      return if @thread.nil?

      redis.method_push EXIT_TOKEN
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

      # Register methods used by this resource class
      redis.register_methods @resource.remote_methods

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

          method, params = redis.method_get(token)

          info "method: #{method.inspect}"
          info "params: #{params.inspect}"

          begin
            method = validate_method(method, params)

            redis.method_result token, method.call(*params)
          rescue Exception => e
            debug "Method #{token} failed:", e.message
            redis.method_result token, e
          end

          redis.method_done token
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
    def validate_method(method_sym, params)
      unless @resource.remote_methods.include?(method_sym)
        raise NoMethodError.new("Undefined method `#{method_sym}'")
      end

      method = @resource.method(method_sym)

      if (method.arity != 0 && params.nil?)
        raise ArgumentError.new("wrong number of arguments to `#{method_sym}'" \
                      "(0 for #{method.arity})")
      end

      if (method.arity > 0 and method.arity != params.length) or
          (method.arity < 0 and method.arity.abs != params.length and
          (method.arity.abs - 1) != params.length)
        raise ArgumentError.new("wrong number of arguments to `#{method_sym}'" \
                      "(#{params.length} for #{method.arity})")
      end

      method
    end
  end
end
