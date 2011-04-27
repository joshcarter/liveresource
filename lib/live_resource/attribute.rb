require File.join(File.dirname(__FILE__), 'log_helper')
require File.join(File.dirname(__FILE__), 'redis_space')

module LiveResource
  module Attribute

    def initialize_resource(namespace, logger = nil, *redis_params)
      @rs = RedisSpace.new(namespace, logger, *redis_params)
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      # Take declaration like:
      #   remote_reader :foo
      # and create method:
      #   def foo() [...]
      def remote_reader(*methods)
        methods.each do |m|
          define_method("#{m}") do
            @rs.attribute_get(m)
          end
        end
      end
      
      # Take declaration like:
      #   remote_writer :foo
      # and create method:
      #   def foo=(value) [...]
      def remote_writer(*methods)
        methods.each do |m|
          define_method("#{m}=") do |value|
            @rs.attribute_set(m, value)
          end
        end
      end

      # Take declaration like:
      #   remote_accessor :foo
      # and create methods:
      #   def foo() [...]
      #   def foo=(value) [...]
      def remote_accessor(*methods)
        methods.each do |m|
          define_method("#{m}") do
            @rs.attribute_get(m)
          end

          define_method("#{m}=") do |value|
            @rs.attribute_set(m, value)
          end
        end
      end
    end
  end
end
