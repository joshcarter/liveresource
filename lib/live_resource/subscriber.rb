require File.join(File.dirname(__FILE__), 'log_helper')
require File.join(File.dirname(__FILE__), 'redis_space')

module LiveResource
  module Subscriber

    def initialize_resource(namespace, logger = nil, *redis_params)
      @rs = RedisSpace.new(namespace, logger, *redis_params)
    end

    def subscribe
      started = false
      subscriptions = self.class.instance_variable_get :@subscriptions

      thread = Thread.new do
        @rs.subscribe(subscriptions.keys) do |on|
          on.subscribe do |key, total|
            puts "Subscribed to #{key} (#{total} subscriptions)"
          end

          on.message do |key, message|
            message = message.nil? ? nil : YAML::load(message)
            puts "#{key}: #{message}"
            
            # TODO: look up subscription, call method
          end

          on.unsubscribe do |key, total|
            puts "Unsubscribed from #{key} (#{total} subscriptions)"
          end

          puts "Subscriber started"
          started = true
        end

        puts "Subscriber done"
      end

      Thread.pass while !started

      thread
    end

    def unsubscribe
      @rs.unsubscribe
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
        
        puts "Registering subscription callbace #{attribute} -> #{method}"
        
        @subscriptions[attribute.to_sym] = method.to_sym
      end
    end
  end
end
