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
      def remote_reader(*methods)
        methods.each do |m|
          define_method("#{m}") do
            @rs.attribute_get(m)
          end
        end
      end
      
      def remote_writer(*methods)
        methods.each do |m|
          define_method("#{m}=") do |value|
            @rs.attribute_set(m, value)
          end
        end
      end
    end

    
    # def self.included(includer)
    #   singleton_class = class << includer; self; end
    #   
    #   # Take declaration like:
    #   #   remote_reader :foo
    #   # and create method:
    #   #   def foo() attribute_read('foo'); end
    #   singleton_class.class_eval do
    #     define_method :remote_reader do |*methods|
    #       methods.each do |m|
    #         define_method("#{m}") do
    #           puts "get #{m}"
    #           @rs.attribute_get(m)
    #         end
    #       end
    #     end
    #   end
    # 
    #   # Take declaration like:
    #   #   remote_writer :foo
    #   # and create method:
    #   #   def foo=(value) attribute_write('foo', value); end
    #   singleton_class.class_eval do
    #     define_method :remote_writer do |*methods|
    #       methods.each do |m|
    #         includer.module_eval do
    #           define_method("#{m}=") do |value|
    #             puts "set #{m}"
    #             @rs.attribute_set(m, value)
    #           end
    #         end
    #       end
    #     end
    #   end
    # end # self.included
  end
end