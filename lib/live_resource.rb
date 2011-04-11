require 'rubygems'
require 'redis'

class LiveResource
  attr_reader :name
  
  def initialize(name, *redis_params)
    @name = name
    @redis = Redis.new(*redis_params)
  end

  def set(state)
    @redis[@name] = state
    @redis.publish @name, state
  end
  
  def get
    @redis[@name]
  end
  
  def subscribe(&block)
    started = false
    
    thread = Thread.new do
      redis.subscribe(channel) do |on|
        on.subscribe do |channel, subscriptions|
          trace "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end
        
        on.message do |channel, message|
          trace "##{channel}: #{message}"          
          keep_going = block.call(message)    # FIXME: is this the right API?
          
          redis.unsubscribe if !keep_going
        end
        
        on.unsubscribe do |channel, subscriptions|
          trace "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
        end

        trace "Subscriber started"
        started = true
      end
      
      trace "Subscriber done"
    end
    
    Thread.pass while !started
    
    thread
  end
  
protected

  def trace(s)
    puts "- #{@name}: #{@s}"
  end
end