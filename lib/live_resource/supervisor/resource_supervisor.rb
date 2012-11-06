require 'thread'
require 'thwait'

require_relative 'supervisor'
require_relative 'worker'

module LiveResource
  module Supervisor
    class ResourceSupervisor < WorkerSupervisor
      def initialize(poll_interval)
        @threads = ThreadsWait.new
        super(poll_interval)
      end

      def add_resource(resource, options={}, &block)
        worker = ResourceWorker.new(resource, options, block, process_worker_events)
        @events.push({type: :add_worker, worker: worker})
      end

      private

      def wait_loop
        loop do
          break if stopping? and !running_workers?

          begin
            thread = @threads.next_wait
          rescue Exception
            # No more threads?
            thread = nil
          end

          next unless thread

          # look up worker
          worker = @workers.find { |w| w.thread == thread }

          if !worker
            raise RuntimeError, "Worker thread (#{thread}) exited but no such worker found."
          end

          # Restart or suspend worker
          @events.push({type: :worker_exited, worker: worker})
        end
      end

      def process_worker_events
        lambda do |on|
          on.started do |worker|
            # Add this worker's thread to our wait queue
            @threads.join_nowait(worker.thread)
          end
        end
      end
    end
  end
end
