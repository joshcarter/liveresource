require 'live_resource'
require 'test/unit'
require 'thread'

Thread.abort_on_exception = true

class StatePublisherTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
    @trace = false
  end

  def trace(s)
    puts("- #{s}") if @trace
  end
  
  def test_get_state
    resource = LiveResource.new('test_get_state')
    resource.set :foo
    assert_equal :foo, resource.get
  end
  
  def subscribe(name, states)
    thread = Thread.new do
      trace "Subscriber started"

      LiveResource.new(name).subscribe do |new_state|
        trace "Subscriber saw change to #{new_state}"
        states << new_state
        
        # Return true if we should keep going
        new_state != :dead
      end
      
      trace "Subscriber done"
    end
    
    sleep 0.1 # Give subscriber chance to start
    thread
  end
  
  def test_subscribe_to_state
    resource = LiveResource.new('test_subscribe_to_state')
    states = Queue.new

    resource.set :ok  # Starting state

    subscriber = subscribe('test_subscribe_to_state', states)
    
    trace "Setting state (1)"
    resource.set :warning
    
    Thread.pass while (states.length < 1)

    trace "Setting state (2)"
    resource.set :dead

    subscriber.join

    assert_equal :warning, states.pop
    assert_equal :dead, states.pop
  end
end