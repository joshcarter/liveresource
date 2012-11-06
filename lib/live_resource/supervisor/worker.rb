module LiveResource
  module Supervisor

    # Basic state management and event notification for workers.
    class WorkerEvents
      attr_reader :callbacks

      def initialize(*callbacks)
        @callbacks = Hash.new do |hash, key|
          #hash[key] = lambda { |*_| }
          hash[key] = []
        end

        # Set up the callback handlers
        callbacks.each do |callback| 
          callback.call(self) if callback
        end
      end

      def started(&block)
        @callbacks[:started] << block
      end

      def restarted(&block)
        @callbacks[:restarted] << block
      end

      def stopped(&block)
        @callbacks[:stopped] << block
      end

      def suspended(&block)
        @callbacks[:suspended] << block
      end

      def unsuspended(&block)
        @callbacks[:unsuspended] << block
      end

      def killed(&block)
        @callbacks[:killed] << block
      end

      def callback(event, arg)
        @callbacks[event].each { |callback| callback.call(arg) }
      end
    end

    class Worker
      attr_reader :restart_limit
      attr_reader :suspend_period
      attr_reader :start_count
      attr_reader :start_time

      def initialize(options={}, *callbacks)
        defaults = { restart_limit: 5, suspend_period: 120 }
        options.merge!(defaults) { |key, v1, v2| v1 }
        @restart_limit = options[:restart_limit]
        @suspend_period = options[:suspend_period]
        @state = :stopped
        @start_count = 0
        @start_time = 0

        # if no block is given, just use an empty block
        #block = lambda { |*_| } unless block_given?
        #@events = WorkerEvents.new(&block)
        @events = WorkerEvents.new(*callbacks)
      end

      def start
        unless runnable?
          raise RuntimeError, "Attempting to start #{self} in non-runnbable state."
        end
        @start_count = start_count + 1
        @start_time = Time.now
        @state = :running
        @events.callback(:started, self)
      end

      def restart
        @state = :stopped
        start
        @events.callback(:restarted, self)
      end

      def stop
        @state = :stopped
        @events.callback(:stopped, self)
      end

      def suspend
        @state = :suspended
        @events.callback(:suspended, self)
      end

      def unsuspend
        @state = :stopped
        @events.callback(:unsuspended, self)
      end

      def kill
        @events.callback(:killed, self)
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
        "Worker state=#{@state}"
      end
    end

    class ProcessWorker < Worker
      attr_reader :file
      attr_reader :name
      attr_reader :pid

      def initialize(file, name, options={}, *callbacks)
        @file = file
        @name = name
        @pid = 0

        super(options, *callbacks)
      end

      def start
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

        super

        @pid
      end

      def restart
        @pid = 0
        super
      end

      def stop
        @pid = 0
        super
      end

      def suspend
        @pid = 0
        super
      end

      def kill
        if running? and @pid != 0
          Process.kill "INT", @pid unless @pid == 0
        end
        super
      end

      def to_s
        "Worker Process: name=#{@name}, state=#{@state}, pid=#{@pid}, start_count=#{@start_count}"
      end
    end

    class ResourceWorker < Worker
      attr_reader :resource
      attr_reader :thread

      def initialize(resource, options={}, *callbacks)
        @resource = resource
        @thread = nil
        super(options, *callbacks)
      end

      def start
        raise RuntimeError, "Attempting to start #{self} in non-runnbable state." if !self.runnable?

        resource.start
        @thread = @resource.dispatcher.thread

        super

        @thread
      end

      def stop
        @resource.stop
        super
      end

      def kill
        @resource.stop
        super
      end

      def to_s
        "Worker Resource: resource=#{@resource}, state=#{@state}"
      end
    end

    # Since the supervisors use multiple threads, we'd like a thread-safe way to add
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
  end
end
