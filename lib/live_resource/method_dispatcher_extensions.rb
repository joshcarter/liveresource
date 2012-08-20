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

  module MethodDispatcherExtensions
    attr_reader :dispatcher

    def start
      if @dispatcher
        @dispatcher.start
      else
        @dispatcher = MethodDispatcher.new
      end
    end

    def stop
      return if @dispatcher.nil?

      @dispatcher.stop
    end

    def running?
      @dispatcher && @dispatcher.running?
    end
  end
end

