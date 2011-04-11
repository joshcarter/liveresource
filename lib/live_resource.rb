require 'rubygems'
require 'redis'
require 'yaml'
require File.join(File.dirname(__FILE__), 'live_resource', 'worker')

class LiveResource
  attr_reader :name, :redis, :actions, :trace
  
  def initialize(name, *redis_params)
    @name = name
    @redis = Redis.new(*redis_params)
    @actions = {}
    @worker = nil
    @trace = false
  end

  #
  # State maintenance
  #
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
  
  #
  # Actions
  #
  def on(method, proc = nil, &block)
    raise(RuntimeError, "must provide either a block or proc") if (proc.nil? && block.nil?)
    raise(RuntimeError, "cannot provide both a block and a proc") if (proc && block)

    @actions[method.to_sym] = proc || block
  end
  
  def run_worker
    @worker = LiveResource::Worker.new(self, @actions)
  end
  
  def stop_worker
    raise "No worker; cannot stop" if @worker.nil?
    @worker.stop
  end
  
  def more_goes_here
    
    # Choose unique key for this action and store it
    key = nil
    loop do
      key = sprintf("%05d", Kernel.rand(100000))
      break if hsetnx(key, :method, action[:method])
    end
    
  end
  
  def trace(s)
    puts("- #{@name}: #{s}") if @trace
  end
end