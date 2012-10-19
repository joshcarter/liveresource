require 'thread'

module LiveResource
  module Supervisor
    class WorkerProcess
      attr_reader :file
      attr_reader :name
      attr_reader :restart_limit
      attr_reader :suspend_period
      attr_reader :pid
      attr_reader :start_count
      attr_reader :start_time

      def initialize(file, name, restart_limit, suspend_period, &event_callback)
        @file = file
        @name = name
        @restart_limit = restart_limit
        @suspend_period = suspend_period
        @pid = 0
        @start_count = 0
        @start_time = 0
        @state = :stopped
        @event_callback = event_callback
      end

      def start
        raise RuntimeError, "Attempting to start #{self} in non-runnbable state." if !self.runnable?

        begin
          pid = Process.fork
          if pid == nil
            # child
            Signal.trap("INT") do
              exit
            end
            Process.exec @file
          end
        rescue Exception
          # It's possible we can attempt to kill a process in the midst of
          # starting it up. In this case, we simply return nil. The supervisor
          # thread will try to start this process again later, if needed.
          return nil
        end

        @pid = pid
        @state = :running
        @start_count = start_count + 1
        @start_time = Time.now
        @event_callback.call self, :started if @event_callback

        @pid
      end

      def restart
        @state = :stopped
        @pid = 0
        start
      end

      def stop
        @state = :stopped
        @event_callback.call self, :stopped if @event_callback
        @pid = 0
      end

      def suspend
        # this process is suspended and cannot be run
        @state = :suspended
        @event_callback.call self, :suspended if @event_callback
      end

      def unsuspend
        @state = :stopped
        start
      end

      def kill
        if running? and @pid != 0
          Process.kill "INT", @pid unless @pid == 0
        end
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

    # Since the supervisor runs in a separate thread, we'd like a thread-safe way to add
    # workers the list, etc.
    #
    # This is probably not strictly necessary under the MRI, but it seems like a good
    # idea in general.
    class WorkerList
      def initialize
        @mutex = Mutex.new
        @workers = []
      end

      def workers
        @mutex.synchronize { @workers.clone }
      end

      def length
        @mutex.synchronize { @workers.length }
      end

      def add(worker)
        @mutex.synchronize { @workers << worker }
      end

      def remove(worker)
        @mutex.synchronize { @workers.delete worker }
      end

      def remove(worker)
        @mutex.synchronize { @workers.clone }
      end

      def each(&block)
        raise ArgumentError, "Block expected" unless block_given?
        @mutex.synchronize do
          @workers.each do |worker|
            yield worker
          end
        end
      end

      def find(&block)
        raise ArgumentError, "Block explected" unless block_given?
        @mutex.synchronize do
          @workers.find do |worker|
            yield worker
          end
        end
      end
    end

    class ProcessSupervisor
      def initialize
        # List of workers to monitor
        @workers = WorkerList.new

        # Workers we are currently monitoring
        @watch_list = {}

        # Workers which are currently suspended
        @suspend_list = {}

        @stopping = Queue.new
      end
      
      # Supervise a single process at the given path
      def add_process(name, path, options = {}, &event_callback)
        defaults = { restart_limit: 5, suspend_period: 120}
        options.merge!(defaults) { |key, v1, v2| v1 }

        exp_path = File.expand_path(path)
        raise ArgumentError, "#{exp_path} does not exist." unless File.exists? exp_path
        raise ArgumentError, "#{exp_path} is not executable." unless File.executable? exp_path

        @workers.add WorkerProcess.new(exp_path, "#{name} (#{path})",
                                       options[:restart_limit], options[:suspend_period], &event_callback)
      end

      # Supervise all the processes in the given directory.
      def add_directory(name, path, options = {}, &event_callback)
        defaults = { restart_limit: 5, suspend_period: 120, pattern: /^.*$/ }
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

          @workers.add WorkerProcess.new(exp_file, "#{name} (#{file})",
                                         options[:restart_limit], options[:suspend_period],
                                           &event_callback)
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
        raise RuntimeError, "Process Supervisor already running" if @run_thread
        raise RuntimeError, "Process Supervisor is stopping" unless @stopping.empty?
 
        # XXX - debugging
        Thread.abort_on_exception = true
       
        @run_thread = Thread.new do
          loop do
            handle_stopped_workers
            handle_suspended_workers
            handle_running_workers

            # Check for a stop message, otherwise sleep for the
            # poll interval.
            if !@stopping.empty?
              do_stop
              break
            else
              sleep POLL_INTERVAL
            end
          end
        end
      end

      def stop
        raise RuntimeError, "Process Supervisor not running" unless @run_thread
        raise RuntimeError, "Process Supervisor already stopping" unless @stopping.empty?

        # Tell the @run_thread to stop
        @stopping << true

        # Wait for @run_thread to exit
        @run_thread.join

        # Clean up 
        @run_thread = nil
        @stopping.clear
      end

      def running_workers?
        @workers.find { |w| w.running? } != nil
      end

      def num_workers
        @workers.length
      end

      private

      # Start any currently stopped workers. This includes any newly added
      # workers.
      def handle_stopped_workers
        @workers.each do |worker|
          worker.start if worker.stopped?
        end
      end

      # If a worker reaches its restart_limit within its suspend_period (seconds),
      # then suspend it. This is also the number how long workers will remain
      # suspended before attempting to run them again.
      def handle_suspended_workers
        @suspend_list.each_pair do |worker, suspend_time|
          unsuspend worker if ((Time.now.tv_sec - suspend_time) > worker.suspend_period)
        end
      end

      def handle_running_workers
        return unless running_workers?

        # Check to see if any processes have died.
        #pid = Process.waitpid -1, Process::WNOHANG|Process::WUNTRACED
        pid = Process.waitpid -1, Process::WNOHANG

        return unless pid

        # look up worker
        worker = @workers.find { |w| w.pid == pid }

        if !worker
          raise RuntimeError,
            "WorkerProcess with pid=#{pid} exited but no such worker found. workers=#{@workers.inspect}"
        end

        # TODO: logging

        # Start watching the worker if we aren't already
        watch worker unless watching? worker

        # Restart the worker unless it has been suspended
        worker.restart unless suspend worker
      end

      def do_stop
        # Kill all the workers
        @workers.each { |w| w.kill }

        # Wait for them all to stop
        while running_workers?
          pid = Process.waitpid -1, Process::WUNTRACED
          worker = @workers.find { |w| w.pid == pid }
          worker.stop
        end
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
