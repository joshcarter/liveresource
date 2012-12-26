require_relative 'log_helper'
require_relative 'redis_client'
require_relative 'methods/method'
require_relative 'methods/future'

module LiveResource

  # Client object that represents a resource, allowing method calls
  # and getting/setting attributes. Typically these are returned from
  # LiveResource finder methods (all, find, etc).
  class ResourceProxy
    include LiveResource::LogHelper
    include LiveResource::ErrorHelper

    attr_reader :redis_class, :redis_name

    # Create a new proxy given its Redis class and name; typically NOT
    # USED by client code -- use methods of LiveResource::Finders
    # instead.
    def initialize(redis_class, redis_name)
      @redis_class = redis_class
      @redis_name = redis_name
      @redis = RedisClient.new(redis_class, redis_name)
      @remote_methods = @redis.registered_methods
      @remote_attributes = @redis.registered_attributes
    end

    # Proxies attribute and remote method calls to the back-end provider.
    def method_missing(m, *params, &block)
      # Strip trailing ?, ! for seeing if we support method
      sm = m.to_s.sub(/[!,?]$/, '').to_sym

      if @remote_attributes.include?(m)
        # Attribute get/set
        if m.match(/\=$/)
          m = m.to_s.sub(/\=$/, '').to_sym # Strip trailing equal

          remote_attribute_write(m, *params)
        else
          remote_attribute_read(m)
        end
      elsif @remote_methods.include?(sm)
        # Method call
        method = RemoteMethod.new(
                              :method => sm,
                              :params => params)

        if m.match(/!$/)
          # Async call, discard result
          method.flags[:discard_result] = true

          remote_send method
        elsif m.match(/\?$/)
          # Async call with future
          method = remote_send method
          Future.new(self, method)
        else
          # Synchronous method call
          wait_for_done remote_send(method)
        end
      else
        super
      end
    end

    # Checks if method is a supported attribute or remote method.
    #
    # @param [LiveResource::RemoteMethod] method method to send
    # @param [Object] include_private unused
    def respond_to_missing?(method, include_private)
      stripped_method = method.to_s.sub(/[!,?]$/, '').to_sym

      @remote_methods.include?(stripped_method) or
        @remote_attributes.include?(method)
    end

    # Send a already-created method object; not typically used by
    # clients -- use method_missing interface instead.
    #
    # @param [LiveResource::RemoteMethod] method method to send
    def remote_send(method)
      @redis.method_send method
    end

    # Wait for method to finish, blocks if method not complete. An
    # exception raised by the remote resource will be captured and
    # raised in the client's thread. Clients may only wait once for
    # completion.
    #
    # @param [LiveResource::RemoteMethod] method method to wait for
    # @param [Numeric] timeout seconds to wait for method completion
    def wait_for_done(method, timeout = 0)
      result = @redis.method_wait_for_result(method, timeout)

      if result.is_a?(Exception)
        # Merge the backtrace from the passed exception with this
        # stack trace so the final backtrace looks like the method_sender
        # called the method_provider directly.
        trace = merge_backtrace caller, result.backtrace
        result.set_backtrace trace

        tag_errors(LiveResource::ResourceApiError) { raise result }
      else
        result
      end
    end

    # Check if remote method is already complete. May be called multiple times.
    #
    # @param [LiveResource::RemoteMethod] method method to check on
    def done_with?(method)
      @redis.method_done_with? method
    end

    # Reads remote attribute.
    #
    # @param [Symbol] key attribute name
    # @return [Object] remote attribute value
    def remote_attribute_read(key, options = {})
      @redis.attribute_read(key, options)
    end

    # Writes remote attribute to new value.
    #
    # @param [Symbol] key attribute name
    # @param [Object] value new value for attribute
    # @return new value for attribute
    def remote_attribute_write(key, value, options = {})
      @redis.attribute_write(key, value, options)
    end

    def inspect
      "#{self.class}: #{@redis_class} #{@redis_name}"
    end

    # Specify custom format when YAML encoding
    def encode_with coder
      coder.tag = '!live_resource:resource'
      coder['class'] = @redis_class
      coder['name'] = @redis_name
    end

    private

    # Merge the stack trace from the method sendor and method
    # provider so it looks like one, seamless stack trace.
    # LiveResource traces are removed and replaced with a simple
    # 'via LiveResource' type message.
    def merge_backtrace(sender_trace, provider_trace)
      return nil if provider_trace.nil?
      return provider_trace if sender_trace.nil?

      # Find the first live resource stack trace
      index = provider_trace.index do |t|
        t =~ /lib\/live_resource\/methods\/dispatcher/
      end

      # Slice off everything starting at that index
      result = provider_trace[0 .. (index - 1)]

      # Add a trace that indicates that live resource was used
      # to link the sender to the provider.
      result << '<< via LiveResource remote method call >>'

      # For the sender trace, remove the ResourceProxy
      # part of the trace.
      index = sender_trace.index do |t| 
        t =~ /lib\/live_resource\/resource_proxy/
      end
      result += sender_trace[(index + 1) .. (sender_trace.length - 1)]

      result
    end
  end
end

# Make YAML parser create ResourceProxy objects from our custom type.
Psych.add_domain_type('live_resource', 'resource') do |type, val|
  LiveResource::ResourceProxy.new(val['class'], val['name'])
end
