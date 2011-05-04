require 'rubygems'
require 'redis'
require 'yaml'
require File.join(File.dirname(__FILE__), 'live_resource', 'worker')

class LiveResource
  attr_reader :name, :redis, :actions
  attr_accessor :trace
  
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
  def set(state, opts = {})
    state = YAML::dump(state)
    
    @redis[@name] = state
    @redis.publish @name, state

    if opts[:ttl]
      @redis.expire @name, opts[:ttl]
    end
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
  
  def start_worker
    @worker = LiveResource::Worker.new(self)
  end
  
  def stop_worker
    # TODO: only the worker instance will have @worker set; another instance should be able to shut it down (I think?)
    raise "No worker; cannot stop" if @worker.nil?

    @worker.stop
  end
  
  def async_action(method, *params)
    # Choose unique token for this action and store it
    token = nil
    loop do
      token = sprintf("%05d", Kernel.rand(100000))
      break if hsetnx(token, :method, method)
    end
    
    hsetnx(token, :params, *params) unless params.nil?
    
    @redis.lpush("#{@name}.actions", token)
    
    token
  end
  
  def action(method, *params)
    token = async_action(method, params)

    list, result = @redis.brpop "#{@name}.results.#{token}", 0
    result = YAML::load(result)
    
    @redis.del(hash_for(token))
    
    if (result.is_a? Exception)
      raise result.class.new(result.message)
    else
      result
    end
  end
  
  def trace(s)
    puts("- #{@name}: #{s}") if @trace
  end
  
  private
  
  def hash_for(token)
    "#{@name}.actions.#{token}"
  end
  
  def hsetnx(token, key, value)
    trace("hsetnx #{hash_for(token)} #{key}: #{value}")
    @redis.hsetnx(hash_for(token), key, YAML::dump(value))
  end
  
  def hset(token, key, value)
    trace("hset #{hash_for(token)} #{key}: #{value}")
    @redis.hset(hash_for(token), key, YAML::dump(value))
  end
  
  def hget(token, key)
    trace("hget #{hash_for(token)} #{key}")
    value = @redis.hget(hash_for(token), key)
    trace(" -> #{value}")
    YAML::load(value)
  end
end
