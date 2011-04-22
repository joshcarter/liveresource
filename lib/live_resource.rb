require 'rubygems'
require 'redis'
require 'yaml'
require File.join(File.dirname(__FILE__), 'live_resource', 'worker')

class LiveResource
  attr_reader :name, :redis, :actions
  attr_accessor :trace
  
  # call-seq:
  #   LiveResource.new(name, redis_params = nil) -> LiveResource
  #
  # Create a new LiveResource instance with specified name. Additional
  # parameters are passed to Redis; for example host name and port of
  # your redis server.
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
  
  # call-seq:
  #   LiveResource.set(new_state) -> new_state
  #
  # Update state to new_state. If new_state is different than before, the
  # state will be published to any subscribers. State may be any Ruby
  # object (including collections).
  def set(state)
    state = YAML::dump(state)

    # Don't publish duplicate states
    return if (state == @redis[@name])    
    
    @redis[@name] = state
    @redis.publish @name, state
    state
  end
  
  # call-seq:
  #   LiveResource.get -> state
  #
  # Get current state. Returns nil if no state has been set.
  def get
    value = @redis[@name]
    
    value.nil? ? nil : YAML::load(value)
  end
  
  # call-seq:
  #   LiveResource.subscribe(&block) -> thread
  #
  # Create a new thread and subscribe to state changes for this resource.
  # Block will be called once for every new state published. Use
  # +unsubscribe+ to stop the subscriber thread.
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
  
  # call-seq:
  #   LiveResource.unsubscribe
  #
  # Stop all subscribers. Threads will exit on their own; if you need to
  # wait for the subscriber to exit, call +join+ on the subscriber thread.
  def unsubscribe
    @redis.unsubscribe
  end
  
  #
  # Actions
  #
  
  # call-seq:
  #   LiveResource.on(method, proc = nil, &block = nil)
  #
  # Register the block (or lambda) to be called when an action matching
  # +method+ is called by another LiveResource client. Return value of
  # the block is the value returned to the client. Must also call
  # +start_worker+ before the resource will handle actions.
  def on(method, proc = nil, &block)
    raise(RuntimeError, "must provide either a block or proc") if (proc.nil? && block.nil?)
    raise(RuntimeError, "cannot provide both a block and a proc") if (proc && block)

    @actions[method.to_sym] = proc || block
  end
  
  # call-seq:
  #   LiveResource.start_worker -> thread
  #
  # Start worker thread, allowing actions to be handled.
  def start_worker
    raise "Worker already running" if @worker
    
    @worker = LiveResource::Worker.new(self)
  end

  # call-seq:
  #   LiveResource.stop_worker
  #
  # Stop worker thread. Will not return until worker is stopped.
  def stop_worker
    # TODO: only the worker instance will have @worker set; another
    # instance should be able to shut it down (I think?)
    raise "No worker; cannot stop" if @worker.nil?

    @worker.stop
  end
  
  # call-seq:
  #   LiveResource.async_action(method, *params) -> token
  #
  # Queue an action for a remote worker to perform. Returns a token which
  # can be used with +done_with?+ and +wait_for_done+.
  def async_action(method, *params)
    # Choose unique token for this action; retry if token is already in
    # use by another action.
    token = nil
    loop do
      token = sprintf("%05d", Kernel.rand(100000))
      break if hsetnx(token, :method, method)
    end
    
    hsetnx(token, :params, params) unless params.nil?
    
    @redis.lpush("#{@name}.actions", token)
    
    token
  end

  # call-seq:
  #   LiveResource.done_with?(token) -> true or false
  #
  # Check to see if an in-progress action is done. Raises ArgumentError
  # if the action's results have already been retreived, or if the token
  # is otherwise invalid.
  def done_with?(token)
    if @redis.exists "#{@name}.results.#{token}"
      true
    elsif token == @redis.lindex("#{@name}.action_in_progress", 0)
      false
    else
      raise ArgumentError.new("No action #{token} pending")
    end
  end
  
  # call-seq:
  #   LiveResource.wait_for_done(token) -> result
  #
  # Wait for action to complete and return its result. If the result is
  # an exception, the exception will be raised. After calling 
  # +wait_for_done+, the result (and other details about this action)
  # will be deleted and the passed-in token will be invalid. 
  # 
  # Note: May use +done_with?+ to check if the action is already done,
  # in which case this will return the result immediately.
  def wait_for_done(token)
    list, result = @redis.brpop "#{@name}.results.#{token}", 0
    result = YAML::load(result)

    @redis.del(hash_for(token))
    
    if result.is_a?(Array) and result[0].is_a?(Exception)
      # See note in Worker.set_result about this
      exception = result[0].class.new(result[1])
      raise exception
    else
      result
    end
  end
  
  # call-seq:
  #   LiveResource.action(method, *params) -> result
  #
  # Perform action via a remote worker and wait for the action to complete.
  # Will block the caller until a result is returned. If the result is an
  # exception, the exception will be raised.
  def action(method, *params)
    wait_for_done async_action(method, *params)
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
