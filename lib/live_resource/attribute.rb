require File.join(File.dirname(__FILE__), 'common')

module LiveResource
  module Attribute
    include LiveResource::Common
    
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
            redis_space.attribute_get(m)
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
            redis_space.attribute_set(m, value)
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
            redis_space.attribute_get(m)
          end

          define_method("#{m}=") do |value|
            redis_space.attribute_set(m, value)
          end
        end
      end
    end
  end
end
