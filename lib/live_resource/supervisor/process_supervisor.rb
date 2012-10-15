# TODO:
# * Logger
# * Clean up WorkerProcess
# * Clean up ProcessSupervisor
# * Add restart tracking
class WorkerProcess
  attr_reader :file
  attr_reader :name
  attr_reader :restart_limit
  attr_reader :pid
  attr_accessor :start_count
  attr_reader :start_time

  def initialize(file, name, restart_limit)
    @file = file
    @name = name
    @restart_limit = restart_limit
    @state = :stopped
    @pid = 0
    @start_count = 0
    @start_time = 0
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
    raise RuntimeError if !self.runnable?

    pid = Process.fork
    if !pid
      # child
      Process.exec file
    end

    @pid = pid
    @state = :running
    @start_count = start_count + 1
    @start_time = Time.now

    @pid
  end

  def restart
    @state = :stopped
    self.start
  end

  def stop
    @state = :stopped
  end

  def kill
    # XXX - signal running process and mark it stopped
  end

  def suspend
    # this process is suspended and cannot be run
    @state = :suspended
  end

  def unsuspend
    @state = :stopped
  end
end

class ProcessSupervisor
  def initialize
    # List of workers to monitor
    @workers = []
  end

  # Supervise a single process at the given path
  def add_process(name, path, options)
    defaults = { restart_limit: 5 }
    options.merge!(defaults) { |key, v1, v2| v1 }

    raise ArgumentError if !File.exists? path or !File.executable? path

    workers << WorkerProcess.new(File.expand_path(path), "#{name} (#{path})", options[:restart_limit])
  end

  # Supervise all the processes in the given directory.
  def add_directory(name, path, options)
    defaults = { restart_limit: 5, pattern: /^.*$/ }
    options.merge!(defaults) { |key, v1, v2| v1 }

    path = File.expand_path(path)
    raise ArgumentError if !File.exists? path or !File.directory? path

    # Open up the directory and create workers
    # for all the files which are executable and
    # match the user-specified pattern (if given).
    # pattern
    Dir.foreach(path) do |file|
      next if File.directory? file or !File.executable? file
      md = file.match options[:pattern]
      next if !md

      workers << WorkerProcess.new(File.expand_path(file, path), "#{name} (#{file})", options[:restart_limit])
    end

    # TODO: warn if no workers added.
    
  end

  def run
    # Start all the workers
    workers.each { |worker| worker.start }

    loop do
      pid = Process.waitpid -1, 0

      next if !pid

      # look up worker
      worker = @workers.find { |w| w.pid == pid }
      if !worker
        # TODO: logging
        # TODO: exception?
        next
      end

      # TODO: logging
      
      # TODO: handle suspending workers which are in restart loop

      # restart the worker
      worker.restart
    end
  end
end
