require 'live_resource'
require 'test/unit'
require 'thread'

class StatePublisherTest < Test::Unit::TestCase
  def setup
    @state = LiveResource.new(:happy)   # FIXME: how do I tell the LR what its attribute should be called?
                                        # - consider defining as aliases to get/set, vs. define_method()
  end

  def test_true
    true
  end

  def DISABLED_test_get_state
    assert_equal :happy, @state.happiness
  end
  
  def DISABLED_test_subscribe_to_state
    states = Queue.new
    subscriber_started = false
    subscriber_quit = Queue.new

    subscriber = Thread.new do
      trace "Subscriber started"

      @state.subscribe(:happiness) do |new_state|
        trace "Subscriber saw change to #{new_state}"
        states << new_state
        break if (new_state == :sad)
      end
      
      subscriber_started = true
    
      subscriber_quit.pop
      trace "Subscriber done"
    end
    
    Thread.pass while !subscriber_started
    
    @state.happiness = :giddy
    
    Thread.pass while (states.length < 1)

    @state.happiness = :sad

    subscriber.join

    assert_equal :giddy, states.pop
    assert_equal :sad, states.pop
  end
end