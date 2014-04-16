require_relative 'live_resource/resource'
require_relative 'live_resource/supervisor'
require 'set'

# LiveResource is a framework for coordinating processes and status
# within a distributed system. Consult the documention for
# LiveResource::Resource for attribute and method providers,
# LiveResource::Finders for discovering resources, and
# LiveResource::ResourceProxy for using resources.
module LiveResource
  class << self
    # Register the resource. Note that the resource must first be started
    # before it can be discovered and methods can be called on it.
    #
    # @param resource [LiveResource::Resource] the object to register
    def register(resource, *instance_init_params)
      resources << resource
  
      resource.register instance_init_params
    end
  
    # Unregister the resource, removing it from discovery and stopping
    # its method dispatcher. This method will block until the method
    # dispatcher is stopped.
    #
    # @param resource [LiveResource::Resource] the object to unregister
    def unregister(resource)
      resource.stop
  
      resources.delete resource
    end
  
    # Start all resources. Usually not needed since registering a
    # resource automatically starts it; however if you stopped
    # LiveResource manually, this will let you re-start all registered
    # resources.
    def start
      resources.each do |resource|
        resource.start
      end
    end
  
    # Stop all resources, preventing methods from being called on them.
    def stop
      resources.each do |resource|
        resource.stop
      end
    end
  
    # Stop and unregister all resources
    def shutdown
      resources.each do |r|
        unregister r
      end
    end
  
    # Run LiveResource until the exit_signal (default=SIGINT) is recevied.
    # Optionally invoke the exit callback before exiting.
    def run(exit_signal="INT", &exit_cb)
      Signal.trap(exit_signal) do
        Thread.new do
          stop
          yield if exit_cb
          exit
        end
      end
  
      # Put this thread to sleep
      sleep
    end

  private

    def resources
      @resources ||= Set.new
    end    
  end
end
