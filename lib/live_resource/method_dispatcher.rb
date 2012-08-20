module LiveResource
  class MethodDispatcher
    attr_reader :thread, :target
    EXIT_TOKEN = 'exit'

    def initialize(target)
      @target = target
      @thread = nil

      start
    end

    def start
      return if @thread

      @thread = Thread.new { run }
    end

    def stop
      return if @thread.nil?

      redis.method_push(self, EXIT_TOKEN)
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
      redis.hincrby @target.redis_class, @target.redis_name, 1

      begin
        loop do
          token = redis.method_wait(self)

          if token == EXIT_TOKEN
            redis.method_done self, token
            break
          end

        end
      ensure
        # NOTE: if this process crashes outright, or we lose network
        # connection to Redis, or whatever -- this decrement won't occur.
        # Supervisor should clean up where possible.

        redis.hincrby @target.redis_class, @target.redis_name, -1
        info("#{self} method dispatcher exiting")
      end
    end
  end
end
