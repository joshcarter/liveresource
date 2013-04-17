require_relative 'worker'

module LiveResource
  module Supervisor
    # Base class for supervisors
    class WorkerSupervisor
      def initialize(poll_interval)
        @poll_interval = poll_interval

        # List of workers to monitor
        @workers = WorkerList.new

        # Workers we are currently monitoring
        @watch_list = {}

        # Workers which are currently suspended
        @suspend_list = {}

        # Event queue
        @events = Queue.new

        @stopping = false

        @run_thread = nil
      end

      def run
        raise RuntimeError, "Supervisor already running" if @run_thread
        raise RuntimeError, "Supervisor is stopping" if stopping?

        @run_thread = Thread.new do
          poll_thread = Thread.new { poll_loop }
          wait_thread = Thread.new { wait_loop }

          # Primary event loop. Wait for events and then process.
          # Classes inheriting from the Supervisor base class  will
          # most likely overide the various event handlers and possibly
          # the poll/wait loops.
          loop do
            break if stopping? and !running_workers?
            event = @events.pop
            case event[:type]
            when :poll
              do_poll
            when :stop
              do_stop
            when :add_worker
              do_add event[:worker]
            when :worker_exited
              do_exited_worker event[:worker]
            end
          end

          poll_thread.join
          wait_thread.join
        end
      end

      def stop
        raise RuntimeError, "Supervisor not running" unless @run_thread
        raise RuntimeError, "Supervisor already stopping" if @stopping

        # Tell the @run_thread to stop
        @events.push({type: :stop})

        # Wait for @run_thread to exit
        @run_thread.join

        # Clean up 
        @run_thread = nil
        @stopping = false
      end

      def running_workers?
        @workers.find { |w| w.running? } != nil
      end

      def num_workers
        @workers.length
      end

      def stopping?
        @stopping
      end

      private

      # The basic poll loop is simple. Push a poll event every @poll_interval
      # seconds. This provides the ability to do long polling while being
      # mostly event-driven.
      def poll_loop
        loop do
          sleep @poll_interval
          break if stopping?
          @events.push({type: :poll})
        end
      end

      # The basic wait loop doesn't do anything. Classes inheriting from the
      # base supervisor class will likely override this method with wait mechanisms
      # specific to the kinds of workers they are managing.
      def wait_loop
        loop do
          break if stopping?
          Thread.pass
        end
      end

      def do_poll
        return if stopping?

        process_suspended_workers
        process_stopped_workers
      end

      def do_add(worker)
        return if stopping?

        # add the worker
        @workers.add worker

        # Start any stopped workers (this would include the newly added worker).
        process_stopped_workers
      end

      def do_exited_worker(worker)
        if stopping?
          worker.stop
        else
          process_exited_worker(worker)
        end
      end

      # Unsuspend workers who have been suspended for their suspend period.
      # If a block is a given, yield any workers which are unsuspended.
      def process_suspended_workers(&block)
        @suspend_list.each_pair do |worker, suspend_time|
          if ((Time.now.tv_sec - suspend_time) > worker.suspend_period)
            unsuspend worker
            yield worker if block_given?
          end
        end
      end

      # Start any currently stopped workers. This includes any newly added workers.
      # If a block is given, yield the result of any workers being started (usually
      # this would be a process id or thread which the caller can use for tracking
      # purposes).
      def process_stopped_workers(&block)
        @workers.each do |worker|
          if worker.stopped?
            result = worker.start
            yield result if block_given?
          end
        end
      end

      # Exited workers are placed on the watch list and then restarted
      # unless they get suspended.
      def process_exited_worker(worker)
        # Start watching the worker if we aren't already
        watch worker unless watching? worker

        # Restart the worker unless it has been suspended
        worker.restart unless suspend worker
      end

      # Place supervisor in stopping state and kill all the workers.
      def do_stop
        @stopping = true

        # Kill all the workers
        @workers.each { |w| w.kill }
      end

      # Start watching a worker
      def watch(worker)
        raise RuntimeError, "Attempting to watch suspended worker." if suspended? worker

        # Note, if we "re-watch" a worker, its time/count get reset
        @watch_list[worker] = {time: Time.now.tv_sec, count: worker.start_count}
      end

      def unwatch(worker)
        raise RuntimeError, "Worker not being watched" unless watching? worker
        @watch_list.delete worker
      end

      def watching?(worker)
        true if @watch_list[worker]
      end

      # If a worker reaches its restart_limit within its suspend_period (seconds),
      # then suspend it. This is also how long workers will remain suspended before
      # attempting to run them again.
      def suspend(worker)
        return false unless watching? worker or suspended? worker

        watch_info = @watch_list[worker]

        # Check if we are still in the suspend period
        if ((Time.now.tv_sec - watch_info[:time]) > worker.suspend_period)
          # We can unwatch this worker
          unwatch worker
          return false
        end

        # We are still in the suspend period, check the restart_count
        if ((worker.start_count - watch_info[:count]) < worker.restart_limit)
          # Worker is okay for now.
          return false
        end

        # Worker should be suspended.
        unwatch worker
        @suspend_list[worker] = Time.now.tv_sec
        worker.suspend
        true
      end

      def unsuspend(worker)
        raise RuntimeError, "Worker not suspended" unless suspended? worker
        @suspend_list.delete worker
        worker.restart
      end

      def suspended?(worker)
        true if @suspend_list[worker]
      end
    end
  end
end
