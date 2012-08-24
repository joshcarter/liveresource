module LiveResource
  module Declarations
    def resource_name
      # Class-level resource_name is an attribute we fetch to determine
      # the instance's name
      attr = self.class.instance_variable_get(:@resource_name)

      if attr
        self.send(attr)
      else
        raise "can't get resource name for #{self.class.to_s}"
      end
    end

    def resource_class
      self.class.instance_variable_get(:@resource_class)
    end

    module ClassMethods
      # FIXME: comment this
      def resource_name(attribute_name = nil)
        if attribute_name
          @resource_name = attribute_name.to_sym
        else
          @resource_class
        end
      end

      # FIXME: comment this
      def resource_class(class_name = nil)
        if class_name
          @resource_class = class_name
        else
          "class"
        end
      end
    end
  end
end
