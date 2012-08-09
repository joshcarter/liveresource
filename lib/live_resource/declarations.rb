module LiveResource
  module Declarations
    def resource_name
      # FIXME: this should look at class-level @resource_name, then
      # eval any ERB in there to create an instance resource name.
      self.object_id.to_s
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      def resource_name=(pattern)
        raise "Not yet implemented"
        # @resource_name = name
      end

      def resource_class=(class_name)
        @resource_class = class_name
      end
      
      def resource_class
        @resource_class ||= self.class
      end
    end    
  end
end