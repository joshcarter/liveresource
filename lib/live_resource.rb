require_relative 'live_resource/resource'

module LiveResource
  def self.register(resource)
    # puts "registering #{resource.to_s}"

    @@resources ||= []
    @@resources << resource

    resource.start
  end

  def self.unregister(resource)
    # puts "unregistering #{resource.to_s}"

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
end
