module LiveResource
  def self.register(resource)
    @@resources ||= []
    @@resources << resource
  end
  
  def self.unregister(resource)
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
      
    def run
      info("#{self} method dispatcher starting")
      
      # wait = redis.REDIS_OPS[:method_wait].curry[self]
      wait = -> { redis.method_wait(self) }
      
      loop do
        token = wait[]
        
        if token == EXIT_TOKEN
          redis.method_done self, token
          break
        end

      end

      info("#{self} method dispatcher exiting")
    end
  end
end
