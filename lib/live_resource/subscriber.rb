require File.join(File.dirname(__FILE__), 'log_helper')
require File.join(File.dirname(__FILE__), 'redis_space')

module LiveResource
  module Subscriber
    UNSUBSCRIBE_KEY = :unsubscribe_key

    # include LogHelper # FIXME

    def initialize_resource(namespace, logger = nil, *redis_params)
      # logger ||= Logger.new(STDOUT)  # FIXME
      # logger.level = Logger::DEBUG
      
      @namespace = namespace
      @rs = RedisSpace.new(namespace, logger, *redis_params)
      @rs_secondary = RedisSpace.new(namespace, logger, *redis_params)
      # initialize_logger(logger) # FIXME
    end

    def subscribe
      ready = false
      subscriptions = self.class.instance_variable_get :@subscriptions
      channels = [UNSUBSCRIBE_KEY] + subscriptions.keys

      @thread = Thread.new do
        @rs.subscribe(channels) do |on|
          on.subscribe do |key, total|
            puts "Subscribed to #{key} (#{total} subscriptions)"

            if (channels.length == total)
              puts "Subscriber ready"
              ready = true
            end
          end

          on.message do |key, new_value|
            # Need to strip namespace from key; callbacks were registered
            # before namespace was known (at initialize).
            namespace_length = @namespace.length + 1 # Include '.' separator
            key = key.to_s
            key = key[namespace_length, key.length - namespace_length]
            key = key.to_sym
            
            # De-serialize value
            new_value = new_value.nil? ? nil : YAML::load(new_value)

            puts "#{key.inspect} changed value to #{new_value.inspect}"
            
            if key.to_s.end_with? UNSUBSCRIBE_KEY.to_s
              @rs.unsubscribe
              next
            end
            
            m = subscriptions[key]
            
            if m.nil?
              warn "Received subscription update for unknown key #{key}"
              next
            end

            send m, new_value
          end

          on.unsubscribe do |key, total|
            puts "Unsubscribed from #{key} (#{total} subscriptions)"
          end

          puts "Subscriber thread started"
        end

        puts "Subscriber thread done"
      end

      Thread.pass while !ready

      @thread
    end

    def unsubscribe
      # Need to publish on secondary RedisSpace because the first one is
      # blocked waiting for subscription updates.
      @rs_secondary.publish UNSUBSCRIBE_KEY, true
      @thread.join
    end
    
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def remote_subscription(attribute, method = nil)
        @subscriptions ||= Hash.new

        if @subscriptions[attribute]
          throw ArgumentError, "Subscription callback already defined for attribute #{attribute}"
        end
        
        # If method isn't specified, assume it matches the attribute name.
        method ||= attribute
        
        @subscriptions[attribute.to_sym] = method.to_sym
      end
    end
  end
end
