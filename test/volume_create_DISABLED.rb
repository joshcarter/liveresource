require_relative 'test_helper'

class VolumeResource
  include LiveResource::Resource
  
  resource_type :volume
  resource_name "<%= self.name %>"

  remote_attribute :name, :status
  remote_method :start, :stop
  
  # Internal-only volume create methods
  remote_method :stage1_create_gluster_config
  remote_method :stage2_create_gluster_config_done

  # TODO:
  # Implicit in declaring remote_class_method :new
  # class << self
  #   alias_method object_new new
  # end
  #
  remote_class_method :new

  def initialize(name)
    @name = name
    
    LiveResource::Worker::register(self)
  end
  
  def self.new(name)
    info "creating new volume #{name}"
    v = VolumeResource.object_new(name)

    v.status = :creating    
    v.stage1_create_gluster_config!
  end
  
  def stage1_create_gluster_config
    params = { } # stuff here that Gluster needs

    # This builds up a state object that's returned to the method dispatcher.
    # - Instead of reply, this is a forward
    # - It goes to a :gluster instance
    # - The new method and params are wrapped up in same way as a new method call
    # - There's a hidden parameter which specifies the continuation method
    LiveResource::any(:gluster).forward(:create_config, self).continue_to(:stage2_create_gluster_config_done)
  end
  
  # Return values from remote methods:
  # - Explicit reply
  # - Forward to another actor
  # - Something else, that gets treated as a reply
  #
  # Method dispatcher may already have state for continuing to another method.
  
  def stage2_create_gluster_config_done
    @status = :stopped
  end
end

class GlusterResource
  include LiveResource::Resource
  
  resource_type :gluster
  resource_name "<%= self.hostname %>"
  
  remote_method :create_config
  
  def create_config(volume)
    # do gluster stuff here to set up volume

    nil # No params necessary
  end
end