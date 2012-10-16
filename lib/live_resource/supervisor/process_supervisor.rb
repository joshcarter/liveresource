module LiveResource
  module Supervisor
    class WorkerProcess
      attr_reader :file
      attr_reader :name
      attr_reader :restart_limit
      attr_reader :pid
      attr_reader :start_count
      attr_reader :start_time

      def initialize(file, name, restart_limit)
        @file = file
        @name = name
        @restart_limit = restart_limit
        @pid = 0
        @start_count = 0
        @start_time = 0
        @state = :stopped
      end

      def stopped?
        @state == :stopped
      end

      def runnable?
        stopped?
      end

      def running?
        @state == :running
      end

      def start
        raise RuntimeError, "Attempting to start #{self} in non-runnbable state." if !self.runnable?

        pid = Process.fork
        if pid == nil
          # child
          Process.exec @file
        end

        @pid = pid
        @state = :running
        @start_count = start_count + 1
        @start_time = Time.now

        @pid
      end

      def restart
        @state = :stopped
        start
      end

      def stop
        @state = :stopped
      end

      def suspend
        # this process is suspended and cannot be run
        @state = :suspended
      end

      def unsuspend
        @state = :stopped
        start
      end

      def stopped?
        @state == :stopped
      end

      def runnable?
        stopped?
      end

      def running?
        @state == :running
      end

      def suspended?
        @state == :suspended
      end

      def to_s
        "Worker Process: name=#{@name}, state=#{@state}, pid=#{@pid}, start_count=#{@start_count}"
      end
    end

    class ProcessSupervisor
      def initialize
        # List of workers to monitor
        @workers = []

        # Workers we are currently monitoring
        @watch_list = {}

        # Workers which are currently suspended
        @suspend_list = {}
      end

      # Supervise a single process at the given path
      def add_process(name, path, options)
        defaults = { restart_limit: 5 }
        options.merge!(defaults) { |key, v1, v2| v1 }

        exp_path = File.expand_path(path)
        raise ArgumentError, "#{exp_path} does not exist." unless File.exists? exp_path
        raise ArgumentError, "#{exp_path} is not executable." unless File.exists? exp_path

        @workers << WorkerProcess.new(exp_path, "#{name} (#{path})", options[:restart_limit])
      end

      # Supervise all the processes in the given directory.
      def add_directory(name, path, options)
        defaults = { restart_limit: 5, pattern: /^.*$/ }
        options.merge!(defaults) { |key, v1, v2| v1 }

        exp_path = File.expand_path(path)
        raise ArgumentError, "#{exp_path} does not exist." unless File.exists? exp_path
        raise ArgumentError, "#{exp_path} is not a directory." unless File.directory? exp_path

        # Open up the directory and create workers
        # for all the files which are executable and
        # match the user-specified pattern (if given).
        # pattern
        workers_added = false
        Dir.foreach(exp_path) do |file|
          exp_file = File.expand_path file, exp_path
          next if File.directory? exp_file or !File.executable? exp_file
          md = file.match options[:pattern]
          next unless md

          @workers << WorkerProcess.new(exp_file, "#{name} (#{file})", options[:restart_limit])
          workers_added = true
        end

        unless workers_added
          raise ArgumentError,
            "No matching, executable workers in #{path} (pattern=#{options[:pattern]})."
        end

      end

      # Polling interval, in seconds
      POLL_INTERVAL = 2

      def run
        # XXX - debugging
        Thread.abort_on_exception = true

        # Start all the workers
        @workers.each { |worker| worker.start }

        loop do
          sleep POLL_INTERVAL

          handle_suspended_workers
          handle_running_workers
        end
      end

      private

      # If a worker reaches its restart_limit within the SUSPEND_PERIOD (seconds),
      # then suspend it. This is also the number how long workers will remain
      # suspended before attempting to run them again.
      SUSPEND_PERIOD = 120

      def handle_suspended_workers
        @suspend_list.each_pair do |worker, suspend_time|
          unsuspend worker if ((Time.now.tv_sec - suspend_time) > SUSPEND_PERIOD)
        end
      end

      def handle_running_workers
        return unless running_workers?

        # Check to see if any processes have died.
        pid = Process.waitpid -1, Process::WNOHANG|Process::WUNTRACED

        return unless pid

        # look up worker
        worker = @workers.find { |w| w.pid == pid }

        if !worker
          # TODO: logging
          # TODO: exception?
          return
        end

        # TODO: logging

        # Start watching the worker if we aren't already
        watch worker unless watching? worker

        # Restart the worker unless it has been suspended
        worker.restart unless suspend worker
      end

      def running_workers?
        @workers.find { |w| w.running? } != nil
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

      def suspend(worker)
        return false unless watching? worker or suspended? worker

        watch_info = @watch_list[worker]

        # Check if we are still in the suspend period
        if ((Time.now.tv_sec - watch_info[:time]) > SUSPEND_PERIOD)
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
