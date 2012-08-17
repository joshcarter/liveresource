module LiveResource
  def self.register(resource)
    puts "registering #{resource.to_s}"

    @@resources ||= []
    @@resources << resource

    resource.start
  end

  def self.unregister(resource)
    puts "unregistering #{resource.to_s}"

    resource.stop

    @@resources.delete resource
  end

  def self.start
    @@resources.each do |resource|
      resource.start
    end
  end

  def self.stop
    @@resources.each do |resource|
      resource.stop
    end
  end

  module MethodDispatcher
    attr_reader :dispatcher_thread
    EXIT_TOKEN = 'exit'

    # Run the method dispatcher in a new Thread, which
    # LiveResource will create.
    def start
      return if @dispatcher_thread

      @dispatcher_thread = Thread.new { run }
    end

    def stop
      return if @dispatcher_thread.nil?

      redis.method_push(self, EXIT_TOKEN)
      @dispatcher_thread.join
      @dispatcher_thread = nil
    end

    def running?
      @dispatcher_thread != nil
    end

    def run
      info("#{self} method dispatcher starting")

      # Need to register our class and instance in Redis so the finders
      # (all, any, etc.) will work.
      redis.hincrby redis_class, redis_name, 1

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

        redis.hincrby redis_class, redis_name, -1
        info("#{self} method dispatcher exiting")
      end
    end
  end
end
