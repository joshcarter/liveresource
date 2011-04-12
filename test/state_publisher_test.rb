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

      resource = LiveResource.new(name)

      resource.subscribe do |new_state|
        trace "Subscriber saw change to #{new_state}"
        states << new_state
        
        resource.unsubscribe if (new_state == :dead)
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
  
  def test_unsubscribe_with_no_subscription
    resource = LiveResource.new('test_unsubscribe_with_no_subscription')
    
    assert_raise(RuntimeError) do
      resource.unsubscribe
    end
  end
  
  def test_subscribe_with_no_initial_state
    resource = LiveResource.new('test_subscribe_with_no_initial_state')    
    states = Queue.new
    
    subscriber = subscribe('test_subscribe_to_state', states)
    
    resource.set :dead
    subscriber.join
    
    assert_equal 0, states.length
  end
  
  def test_multiple_subscribers
    resource = LiveResource.new('test_multiple_subscribers')
    num_subscribers = 5
    num_messages = 100
    states = []
    subscribers = []
    
    num_subscribers.times do
      state_queue = Queue.new
      states << state_queue
      subscribers << subscribe('test_multiple_subscribers', state_queue)
    end
    
    (num_messages - 1).times do |i|
      resource.set "state #{i + 1}"
      Thread.pass if (i % 4) # Pass once in a while
    end

    # Even though we have multiple subscribers, there should only 
    # be one channel in Redis.
    assert_equal 1, Redis.new.info["pubsub_channels"].to_i
    
    resource.set :dead
    
    sleep 0.1
    
    num_subscribers.times do |i|
      subscribers[i].join
    end
    
    assert_equal num_messages, states[0].length
    assert_equal num_messages, states[1].length
    assert_equal num_messages, states[num_subscribers - 1].length
    
    # Should have no junk left over in Redis
    assert_equal 0, Redis.new.info["pubsub_channels"].to_i
  end
end