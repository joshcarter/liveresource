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

      start
    end

    def redis
      LiveResource::redis
    end

    def start
      return if @thread

      @thread = Thread.new { run }
    end

    def stop
      return if @thread.nil?

      redis.method_push @resource, EXIT_TOKEN
      @thread.join
      @thread = nil
    end

    def running?
      @thread != nil
    end

    def run
      info("#{self} method dispatcher starting")

      # Need to register our class and instance in Redis so the finders
      # (all, any, etc.) will work.
      redis.register @resource

      begin
        loop do
          token = redis.method_wait @resource

          if token == EXIT_TOKEN
            redis.method_done @resource, token
            break
          end

        end
      ensure
        # NOTE: if this process crashes outright, or we lose network
        # connection to Redis, or whatever -- this decrement won't occur.
        # Supervisor should clean up where possible.
        redis.unregister @resource

        info("#{self} method dispatcher exiting")
      end
    end
  end
end
