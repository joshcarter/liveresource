require 'set'

module LiveResource
  module Declarations
    def resource_name
      # Getting resource name may be expensive, e.g. if it's coming
      # from Redis. Cache so we don't re-fectch this resource's name
      # more than once.
      return @_cached_resource_name if @_cached_resource_name

      # Class-level resource_name is an attribute we fetch to determine
      # the instance's name
      attr = self.class.resource_name_attr

      if attr
        begin 
          @_cached_resource_name = self.send(attr)
        rescue SystemStackError
          raise "can't get resource name for #{self.class.to_s} (resource name can't depend on reading remote attribute)"
        end
      else
        raise "can't get resource name for #{self.class.to_s} (missing resource name attribute)"
      end
    end

    def resource_class
      self.class.instance_variable_get(:@_resource_class)
    end

    module ClassMethods
      def self.extended(base)
        class << base
          # Override the regular new routine with a custom new
          # which auto-registers and starts the resource.
          alias :ruby_new :new

          def new(*params)
            resource = ruby_new(*params)

            # Resources always auto-regiser themselves. However,
            # only unsupervised resources start on their own. It
            # is the responsibility of the resource supervisor to
            # start supervised resources.
            
            if supervised
              # Register in Redis but do not put this object in the
              # list of registered resources (the relevant supervisor
              # will do that).
              resource.register *params
            else
              LiveResource::register resource, *params
              resource.start unless supervised
            end
            resource
          end
        end
      end

      def supervise
        @_supervised = true
      end

      def supervised
        @_supervised ||= false
        @_supervised
      end

      # FIXME: comment this
      def resource_name(attribute_name = nil)
        if attribute_name
          # Called from class definition to set the attribute from which we get a resource's name.
          @_resource_name = attribute_name.to_sym
        else
          # Get the class-level resource name.
          @_resource_class
        end
      end

      # FIXME: comment this
      def resource_class(class_name = nil)
        if class_name
          # Called from class definition to set the resource's class.
          @_resource_class = class_name.to_sym
        else
          # Get the class-level resource class, which we'll always call :class.
          :class
        end
      end

      # Get the attribute which defines this resource's name. (For internal use only.)
      def resource_name_attr
        @_resource_name
      end

      # call-seq:
      #   remote_reader :attr
      #   remote_reader :attr, { :opt => val }
      #   remote_reader :attr1, :attr2, :attr3
      #
      # Declare a remote attribute reader. A list of symbols is used
      # to create multiple attribute readers.
      def remote_reader(*params)
        @_instance_attributes ||= Set.new
        options = {}

        # One symbol and one hash is treated as a reader with options;
        # right now there are no reader options, so just pop them off.
        if (params.length == 2) && (params.last.is_a? Hash)
          options = params.pop
        end

        # Everything left in params should be a symbol (i.e., method name).
        if params.find { |m| !m.is_a? Symbol }
          raise ArgumentError.new("Invalid or ambiguous arguments to remote_reader: #{params.inspect}")
        end

        params.each do |m|
          @_instance_attributes << m

          define_method("#{m}") do
            remote_attribute_read(m, options)
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
        @_instance_attributes ||= Set.new
        options = {}

        # One symbol and one hash is treated as a writer with options.
        if (params.length == 2) && (params.last.is_a? Hash)
          options = params.pop
        end

        # Everything left in params should be a symbol (i.e., method name).
        if params.find { |m| !m.is_a? Symbol }
          raise ArgumentError.new("Invalid or ambiguous arguments to remote_writer: #{params.inspect}")
        end

        params.each do |m|
          @_instance_attributes << "#{m}=".to_sym

          define_method("#{m}=") do |value|
            remote_attribute_write(m, value, options)
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

      def remote_instance_attributes
        @_instance_attributes ||= Set.new
        @_instance_attributes.to_a
      end

      # Remote-callable methods for an instance.
      def remote_instance_methods
        @_instance_methods ||= Set.new
        @_instance_attributes ||= Set.new

        # Remove all instance attributes, then fiter out private and
        # protected methods.
        (@_instance_methods - @_instance_attributes).find_all do |m|
          if private_method_defined?(m) or protected_method_defined?(m)
            nil
          else
            m
          end
        end
      end

      # Remote-callable methods for a resource class.
      def remote_singleton_methods
        @_singleton_methods ||= Set.new
        c = singleton_class

        # Filter out private and protected methods of the singleton class.
        @_singleton_methods.find_all do |m|
          if c.private_method_defined?(m) or c.protected_method_defined?(m)
            nil
          else
            m
          end
        end
      end

      def method_added(m)
        @_instance_methods ||= Set.new
        @_instance_methods << m
      end

      def singleton_method_added(m)
        @_singleton_methods ||= Set.new
        @_singleton_methods << m
      end

      def supervise
        @_supervised = true
      end
    end
  end
end
