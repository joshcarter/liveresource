require 'thread'
require 'thwait'

require_relative 'supervisor'
require_relative 'worker'

module LiveResource
  module Supervisor
    class ResourceSupervisor < WorkerSupervisor
      def initialize(poll_interval)
        @threads = ThreadsWait.new
        @instance_monitors = {}
        super(poll_interval)
      end

      def add_resource(resource, options={}, &client_callback)
        unless resource.is_a? Class
          raise ArgumentError, "Must specify a class resource. #{resource}"
        end

        options[:client_callback] = client_callback if block_given?

        name = ResourceWorker.worker_name(resource.resource_class, resource.resource_name)
        if @workers.find_by_name(name)
          raise ArgumentError, "Already supervising this resource class: #{resource}"
        end

        # Register the class resource with LR.
        resource.supervise
        resource.register

        # Add a worker for this resource.
        worker = add_resource_worker(resource, options)

        # Add workers for instances which alread exist in Redis.
        add_missing_instances(worker)

        # Create instance monitor
        add_instance_monitor(worker)
      end

      private

      def add_resource_worker(resource, options={})
        options[:internal_callback] = process_worker_events
        worker = ResourceWorker.new(resource, options)
        @events.push({type: :add_worker, worker: worker})
        worker
      end

      # Brute force for now
      def add_missing_instances(class_worker)
        unless class_worker.is_class?
          raise ArgumentError, "Must specify a class resource worker."
        end

        # Get all the registered instances of this class
        instances = class_worker.redis.registered_instances

        instances.each do |i|
          name = ResourceWorker.worker_name(class_worker.resource_name, i)

          # Is there already a worker for this instance?
          next if @workers.find_by_name(name)

          # Add the instance. This will cause the resource to be registered
          # in LiveResource but will not start it.
          init_params = class_worker.redis.instance_params(class_worker.resource_name, i)
          resource = class_worker.resource.new(*init_params)

          # Don't add worker if it doesn't match our name filter.
          next unless resource.resource_name.match(class_worker.name_filter)

          add_resource_worker(resource, class_worker.options)
        end
      end

      def remove_deleted_instance(resource_class, resource_name)
        name = ResourceWorker.worker_name(resource_class, resource_name)
        worker = @workers.find_by_name(name)
        if worker
          # Wait for worker to delete itself if it's still running
          return if worker.running?
          @events.push({type: :worker_deleted, worker: worker})
          worker
        end
      end

      def add_instance_monitor(worker)
        channel = worker.redis.instance_channel

        # Already monitoring instances of this resource class
        return if @instance_monitors[channel]

        instance_monitor = Thread.new do
          subscribed_client = RedisClient.redis.clone
          subscribed_client.subscribe(channel) do |on|
            on.message do |c, msg|
              # TODO: Better messages. Use instance name to make this 
              # more efficient.
              resource_class, resource_name, type = msg.split('.')
              if type == "created"
                add_missing_instances(worker)
              elsif type == "deleted"
                remove_deleted_instance(resource_class, resource_name)
              end
            end
          end
        end
  
        instance_monitor[:name] = "#{self.class.name} instance monitor"

        @instance_monitors[channel] = instance_monitor
      end

      def wait_loop
        loop do
          break if stopping? and not running_workers?

          begin
            thread = @threads.next_wait
          rescue Exception
            # No more workers?
            thread = nil
          end

          unless thread
            # Nothing to do, let another Thread run
            Thread.pass
            next
          end

          # look up worker
          worker = @workers.find { |w| w.thread == thread }

          if !worker
            raise RuntimeError, "Worker thread (#{thread}) exited but no such worker found."
          end

          if worker.resource.deleted?
            # Delete this worker
            @events.push({type: :worker_deleted, worker: worker})
          else
            # Restart or suspend worker
            @events.push({type: :worker_exited, worker: worker})
          end
        end
      end

      def do_stop
        super
        @instance_monitors.each_value do |thread|
          Thread.kill thread
          thread.join
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
