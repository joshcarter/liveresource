module LiveResource
  module Declarations
    def resource_name
      # Class-level resource_name is an attribute we fetch to determine
      # the instance's name
      attr = self.class.resource_name

      if attr
        self.send(attr)
      else
        raise "can't get resource name for #{self.class.to_s}"
      end
    end
  end

  module Resource
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def resource_name(attribute_name = nil)
        if attribute_name
          @resource_name = attribute_name.to_sym
        else
          @resource_name
        end
      end

      def resource_class(class_name = nil)
        if class_name
          @resource_class = class_name
        else
          @resource_class ||= self.class
        end
      end
    end
  end
end
