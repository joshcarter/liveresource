require 'thread'

class TaskHandler
  def initialize(proc = nil, &block)
    raise(ArgumentError, "must provide either a block or proc") if (proc.nil? && block.nil?)
    raise(ArgumentError, "cannot provide both a block and a proc") if (proc && block)

    @task = block ? block : proc
    @queue = Queue.new
    @thread = Thread.new { run }
  end

  def run
    if @task.arity > 0
      # Task gets work from queue
      loop do
        work = @queue.pop
        return if (work == :stop)
        @task.call work
      end
    else
      # Task is free-running, should stop on its own
      @task.call
    end

    @thread = nil
  end

  def stop
    @queue.push :stop
    @thread.join
  end

  def stopped?
    @thread.nil?
  end

  def push(work)
    raise(ArgumentError, "cannot push :stop onto a TaskHandler") if (work == :stop)

    @queue.push work
  end
  alias :<< :push
end
