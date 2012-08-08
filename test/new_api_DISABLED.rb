require_relative 'test_helper'

class VolumeResource
  include LiveResource::Resource
  
  # Class type: "volume-class"
  # Class instance name: "volume-class.{hostname}.{pid}"
  # Instance type: "volume"
  # Instance name: "volume.my_volume_name"
  resource_type :volume
  resource_name "<%= self.name %>"

  # Attribute and method declarations stay the same.
  remote_attribute :name, :online
  remote_method :start, :stop

  # LR will always provide class-namespace methods like all() and 
  # find(&block), implemented on the client side. If any class
  # methods are provided, then we'll also start a class-level method
  # dispatcher.
  remote_class_method :create_volume

  def initialize(name)
    @name = name
    @online = false
    
    LiveResource::Worker::register(self)
  end
  
  def start
    unless @online
      info "starting"
      @online = true
    end
    
    @online
  end
  
  def stop
    if @online
      info "stopping"
      @online = false
    end
    
    @online
  end
  
  def self.create_volume(name)
    info "creating new volume #{name}"
    VolumeResource.new(name)
  end
end

class ModuleTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall

    LiveResource::Worker::register_class(VolumeResource)

    # Run method dispatchers in separate threads; use LR::run to 
    # block while they run (e.g., for a dedicated worker process).
    # Each instance will still have its own thread regardless.
    LiveResource::Worker::start
	end
	
	def teardown
	  # Stop and join method dispatchers
	  LiveResource::Worker::stop
  end
	
	def test_foo
	  # Resource finders:
	  #   LiveResource::all(type)      -> [array]
	  #   LiveResource::find(type)     -> class resource
	  #   LiveResource::find(t,name)   -> resource matching name
	  #   LiveResource::find(t,&block) -> resource matching condition
	  #   LiveResource::first(type)    -> first resource
	  #   LiveResource::any(type)      -> picks one randomly

    # Find on type alone gives the class resource.
	  vc = LiveResource::find(:volume)
	
	  # Sync class-level method call
	  vc.create_volume "foo"
	  
	  # Async class-level call with future
	  done = vc.create_volume!?("bar")
	  
	  # Wait for complete
	  done.value
    
    # Find by resource type and name, in this case name is the same
    # as volume name. (See resource_name declaration above.)
    v1 = LiveResource::find(:volume, "foo")
    
    # Find by resource matching type and block.
    v2 = LiveResource::find(:volume) { |v| v.name == "bar" }
	
	  # Attribute read: only consults Redis
	  assert_equal false, v1.online
	  
	  # Syncronous method call, blocks until complete
	  assert_equal true, v1.start
    assert_equal true, v1.online

    # Async method call
    v2.start!
    10.times { Thread.pass }
    assert_equal true, v2.online

    # Async method with future
    done = []
    
    # Note: each applies to instances, excluding the class instance.
    LiveResource::each(:volume) { |v| done << v.stop!? }
    
    begin
      done.each { |d| d.value }
    rescue e
      # Log error and continue waiting for others to complete.
      nil
    end
    
    ## TODO: wrap the above construct in one method that takes one
    # block for the action, another for completion action.
  end
end