require_relative 'supervisor/declarations'
require_relative 'supervisor/process_supervisor'

module LiveResource
  module Supervisor
    def self.included(base)
      base.extend(LiveResource::Supervisor::Declarations::ClassMethods)
    end

    def process_supervisor
      self.class.instance_variable_get(:@_process_supervisor)
    end

    def resource_supervisor
      self.class.instance_variable_get(:@_resource_supervisor)
    end

    # Run the process and resources supervisors in their own threads. The main
    # thread simply sleeps.
    def run
      # There must be at least one configured supervisor in order to run.
      raise RuntimeError unless process_supervisor or resource_supervisor

      # TODO: monitor these threads in case they crash?
      Thread.new { process_supervisor.run } if process_supervisor 
      Thread.new { resource_supervisor.run } if resource_supervisor

      sleep
    end
  end
end
