module LiveResource
  module Supervisor
    module Declarations
      module ClassMethods
        def supervise_directory(name, path, options = {})
          @_process_supervisor ||= LiveResource::Supervisor::ProcessSupervisor.new
          @_process_supervisor.add_directory name, path, options
        end

        def supervise_process(name, path, options = {})
          @_process_supervisor ||= LiveResource::Supervisor::ProcessSupervisor.new
          @_process_supervisor.add_process name, path, options
        end

        def supervise_class(class_name, options = {})
        end

        def supervise_instance(class_name, options = {})
        end
      end
    end
  end
end
