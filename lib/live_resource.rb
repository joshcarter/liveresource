require 'rubygems'
require 'redis'
require 'yaml'

class LiveResource
  attr_reader :name
  
  def initialize(name, *redis_params)
    @name = name
    @redis = Redis.new(*redis_params)
    @trace = false
  end

  def set(state)
    state = YAML::dump(state)
    
    @redis[@name] = state
    @redis.publish @name, state
  end
  
  def get
    value = @redis[@name]
    
    value.nil? ? nil : YAML::load(value)
  end
  
  def subscribe(&block)
    started = false
    
    thread = Thread.new do
      @redis.subscribe(@name) do |on|
        on.subscribe do |channel, subscriptions|
          trace "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end
        
        on.message do |channel, message|
          message = message.nil? ? nil : YAML::load(message)
          trace "##{channel}: #{message}"          
          block.call(message)
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
  
  def unsubscribe
    @redis.unsubscribe
  end
  
protected

  def trace(s)
    puts("- #{@name}: #{s}") if @trace
  end
end