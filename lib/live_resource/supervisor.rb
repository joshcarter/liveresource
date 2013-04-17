require_relative 'supervisor/process_supervisor'
require_relative 'supervisor/resource_supervisor'

# Main supervisor class. This can be used to monitor both processes
# and resources. The real work is done in the ProcessSupervisor
# and ResourceSupervisor class
#
# Some more ideas for options:
# - resources can be supervised as a process or as a Thread
#   in process.
#   - processes are black-box resources. We start/restart
#     them but do not have any conception of what they do. We
#     don't understand their connection to live_resource as a whole such
#     as what their :resource_class is or what their instances are.
#   - thread-based resources are white-box. We can perform all the same
#     actions that we do on processes, but we can also manage their
#     instances and potentially communicate with them via LiveResource.
# - restart_limit and restart_period are configurable on a
#   per-resource basis.
# - TODO: there should be a run-once option for short-lived resources. These
#   resources are essentially not monitored.
# - TODO: new resources can be managed at runtime, that is we can add new resources
#   after we've started the main monitoring loop, and they will get started
# - XXX - open question: how to handle communication between supervisor
#   and white-box resources. just go over LR? or use an in-process queue?
# - ThreadWait class! exactly what I wanted. Why didn't I find that before?
#   Whoop! Whoop!
module LiveResource
  module Supervisor
    class Supervisor

      PROCESS_POLL_INTERVAL = 2
      RESOURCE_POLL_INTERVAL = 2

      attr_reader :process_supervisor
      attr_reader :resource_supervisor

      def initialize
        @process_supervisor = nil
        @resource_supervisor = nil
      end

      # Supervise a single process given by "path"
      def supervise_process(name, path, options={}, &block)
        @process_supervisor ||= LiveResource::Supervisor::ProcessSupervisor.new(PROCESS_POLL_INTERVAL)
        @process_supervisor.add_process(name, path, options, &block)
      end

      # Supervise a set of processes whose executables live
      # underneath the given path. Note options include a regex
      # on how to match the executables. Default is "all files"
      def supervise_directory(name, path, options={}, &block)
        @process_supervisor ||= LiveResource::Supervisor::ProcessSupervisor.new(PROCESS_POLL_INTERVAL)
        @process_supervisor.add_directory(name, path, options, &block)
      end

      # Supervise a resource of the given class and name. Your supervisor
      # must (obviously) have required the correct files for that class.
      # If no name is given, simply supervise all resources of that type.
      # Other options include a filter on the name to determine how to
      # manage new instances of a resource class that we wish to mirror.
      # Default is no filter (meaning any resource of our class type which
      # appears in LR, we will create our own local instance).
      #
      # XXX - interesting open question on how we know which instances our
      # class-level resource has started. I think perhaps we do some magic
      # in the "new" routine? Or we simply use the instance list.
      #
      # XXX - interesting variation: default is to run in thread inside
      # this process. what if wanted to run a white box resource but in
      # a new process. that should be possible, right? Basically:
      # Process.fork do
      #   LiveResource::register ClassName
      #   LiveResource::run
      # end
      #
      def supervise_resource(resource_class, options={}, &block)
        @resource_supervisor ||= LiveResource::Supervisor::ResourceSupervisor.new(RESOURCE_POLL_INTERVAL)
        @resource_supervisor.add_resource(resource_class, options, &block)
      end

      def restart_process(name)
      end

      def restart_directory(name)
      end

      def restart_resource(resource_class, resource_name=nil)
      end

      def restart_all
      end

      def unsupervise_process(name)
      end

      def unsupervise_directory(name)
      end

      def unsupervise_resource(resource_class, resource_name=nil)
      end

      def run
        @process_supervisor.run if @process_supervisor
        @resource_supervisor.run if @resource_supervisor
      end

      def stop
        @process_supervisor.stop if @process_supervisor
        @resource_supervisor.stop if @resource_supervisor
      end
    end  
  end
end
