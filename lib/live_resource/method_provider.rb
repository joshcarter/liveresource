require File.join(File.dirname(__FILE__), 'common')

module LiveResource
  module MethodProvider
    include LiveResource::Common

    attr_reader :dispatcher_thread
    EXIT_TOKEN = 'exit'
    
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def remote_method(*methods)
        @remote_methods ||= []
        @remote_methods += methods
      end
    end
    
    def start_method_dispatcher
      return if @dispatcher_thread

      @dispatcher_thread = Thread.new { method_dispatcher }
    end
      
    def stop_method_dispatcher
      return if @dispatcher_thread.nil?
      
      # Push to clone of RedisSpace; the first one will be blocked 
      # waiting for a method token to come in. Trying to push to the
      # same client will deadlock.
      redis_space.clone.method_push(EXIT_TOKEN)
      @dispatcher_thread.join
      @dispatcher_thread = nil
    end
      
    def method_dispatcher
      info("#{self} method dispatcher starting")

      loop do
        token = redis_space.method_wait
        debug "#{self} popped token #{token}"
        
        if token == EXIT_TOKEN
          redis_space.method_done token
          break
        end

        method_name = redis_space.method_get token, :method
        params = redis_space.method_get token, :params
        
        method_symbol = self.class.instance_eval do
          @remote_methods &&
          @remote_methods.find { |m| m == method_name }
        end

        if method_symbol.nil?
          message = "#{self} undefined method `#{method_name}'"
          debug message
          redis_space.result_set token, NoMethodError.new(message)
          next
        end
        
        method = method(method_symbol)
        
        if (method.arity != 0 && params.nil?)
          message = "wrong number of arguments to `#{method_name}' (0 for #{method.arity})"
          debug message
          redis_space.result_set token, ArgumentError.new(message)
          next
        end
        
        if (method.arity != params.length)
          message = "wrong number of arguments to `#{method_name}' (#{params.length} for #{method.arity})"
          debug message
          redis_space.result_set token, ArgumentError.new(message)
          next
        end
          
        begin
          redis_space.result_set token, method.call(*params)
        rescue Exception => e
          debug "Method #{token} failed:", message
          redis_space.result_set token, e
        end
        
        redis_space.method_done token
      end

      info("#{self} method dispatcher exiting")
    end
  end
end
