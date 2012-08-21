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
      @thread != nil
    end

    def run
      info("#{self} method dispatcher starting")

      # Register methods used by this resource class
      redis.register_methods @resource.remote_methods

      # Need to register our class and instance in Redis so the finders
      # (all, any, etc.) will work.
      redis.register

      begin
        loop do
          token = redis.method_wait

          if token == EXIT_TOKEN
            redis.method_done token
            break
          end

        end
      ensure
        # NOTE: if this process crashes outright, or we lose network
        # connection to Redis, or whatever -- this decrement won't occur.
        # Supervisor should clean up where possible.
        redis.unregister

        info("#{self} method dispatcher exiting")
      end
    end
  end
end
