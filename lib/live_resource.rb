require_relative 'live_resource/resource'
require 'set'

# LiveResource is a framework for coordinating processes and status
# within a distributed system. Consult the documention for
# LiveResource::Resource for attribute and method providers,
# LiveResource::Finders for discovering resources, and
# LiveResource::ResourceProxy for using resources.
module LiveResource
  # Register the resource, allowing its discovery and methods to be
  # called on it. This method will block until the resource is fully
  # registered and its method dispatcher is running.
  #
  # @param resource [LiveResource::Resource] the object to register
  def self.register(resource)
    # puts "registering #{resource.to_s}"

    @@resources ||= Set.new
    @@resources << resource

    resource.start
  end

  # Unregister the resource, removing it from discovery and stopping
  # its method dispatcher. This method will block until the method
  # dispatcher is stopped.
  #
  # @param resource [LiveResource::Resource] the object to unregister
  def self.unregister(resource)
    # puts "unregistering #{resource.to_s}"

    resource.stop

    @@resources.delete resource
  end

  # Start all resources. Usually not needed since registering a
  # resource automatically starts it; however if you stopped
  # LiveResource manually, this will let you re-start all registered
  # resources.
  def self.start
    @@resources.each do |resource|
      resource.start
    end
  end

  # Stop all resources, preventing methods from being called on them.
  def self.stop
    @@resources.each do |resource|
      resource.stop
    end
  end

  # Run LiveResource until the exit_signal (default=SIGINT) is recevied.
  # Optionally invoke the exit callback before exiting.
  def self.run(exit_signal="INT", &exit_cb)
    Signal.trap(exit_signal) do
      self.stop
      yield if exit_cb
      exit
    end

    # Put this thread to sleep
    sleep
  end
end
