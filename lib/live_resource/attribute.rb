require File.join(File.dirname(__FILE__), 'common')

module LiveResource
  module Attribute
    include LiveResource::Common
    
    def remote_modify(attribute, &block)
      # methods returns an array of strings in Ruby 1.8 and an array of
      # symbols in Ruby 1.9.
      unless methods.map { |m| m.to_sym }.include?(attribute.to_sym)
        raise ArgumentError.new("remote_modify: no such attribute '#{attribute}'")
      end
      
      unless block
        raise ArgumentError.new("remote_modify requires a block")
      end

      # Optimistic locking implemented along the lines of:
      #   http://redis.io/topics/transactions
      loop do
        # Watch/get the value
        redis_space.attribute_watch(attribute)
        v = redis_space.attribute_get(attribute)

        # Block modifies the value
        v = block.call(v)
      
        # Set to new value; if ok, we're done. Otherwise we'll loop and
        # try again with the new value.
        redis_space.multi
        redis_space.attribute_set(attribute, v)
        break if redis_space.exec
      end
    end
    
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      # call-seq:
      #   remote_reader :attr
      #   remote_reader :attr1, :attr2, :attr3
      #
      # Declare a remote attribute reader. A list of symbols is used
      # to create multiple attribute readers.
      def remote_reader(*params)
        # One symbol and one hash is treated as a reader with options;
        # right now there are no reader options, so just pop them off.
        if (params.length == 2) && (params.last.is_a? Hash)
          params.pop
        end
        
        params.each do |m|
          define_method("#{m}") do
            redis_space.attribute_get(m)
          end
        end
      end
      
      # call-seq:
      #   remote_writer :attr
      #   remote_writer :attr, { :opt => val }
      #   remote_writer :attr1, :attr2, :attr3
      #
      # Declare a remote attribute writer. One or more symbols are 
      # used to declare writers with default options. This creates
      # methods matching the symbols provided, e.g.:
      #
      #   remote_writer :attr   ->    def attr=(value) [...]
      #
      # One symbol and a hash is used to declare an attribute writer
      # with options. Currently supported options:
      #
      # * :ttl (integer): time-to-live of attribute. After (TTL)
      #   seconds, the value of the attribute returns to nil.
      def remote_writer(*params)
        options = nil

        # One symbol and one hash is treated as a writer with options.
        if (params.length == 2) && (params.last.is_a? Hash)
          options = params.pop
        end
        
        # Everything left in params should be a symbol (i.e., method name).
        if params.find { |m| !m.is_a? Symbol }
          raise ArgumentError.new("Invalid or ambiguous arguments to remote_writer: #{params.inspect}")
        end
        
        params.each do |m|
          define_method("#{m}=") do |value|
            redis_space.attribute_set(m, value, options)
          end
        end
      end

      # call-seq:
      #   remote_accessor :attr
      #   remote_accessor :attr, { :opt => val }
      #   remote_accessor :attr1, :attr2, :attr3
      #
      # Declare remote attribute reader and writer. One or more symbols
      # are used to declare multiple attributes, as in +remote_writer+.
      # One symbol with a hash is used to declare an accessor with
      # options; currently these options are only supported on the 
      # attribute write, and they are ignored on the attribute read.
      def remote_accessor(*params)
        remote_reader(*params)
        remote_writer(*params)
      end
    end
  end
end
