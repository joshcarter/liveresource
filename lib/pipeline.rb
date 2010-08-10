require 'task_handler'

class Pipeline
  # Pipeline stages should be ordered from upstream to downstream
  def initialize(*procs)
    @stages = Array.new

    # If the last stage is a lambda, make a TaskHandler out of it. If it's
    # not a proc, it must be something we can push to.
    #
    if procs.last.class == Proc
      @stages.unshift task_handler_from(procs.last)
    elsif procs.last.respond_to?(:push)
      @stages.unshift procs.last
    else
      raise(ArgumentError, "Final stage must be a proc or respond to push")
    end

    # Construct stages in reverse order since each stage needs to have 
    # a reference to its downstream stage.
    #
    procs[0..-2].reverse.each do |proc|
      downstream = @stages.first
      @stages.unshift task_handler_from(proc, downstream)
    end
  end

  def push(work)
    @stages.first.push work
  end
  alias :<< :push

  def stop
    @stages.each { |s| s.stop if s.respond_to?(:stop) }
  end

  def length
    @stages.length
  end
  
  private

  def task_handler_from(proc, downstream = nil)
    if (proc.class != Proc)
      raise(ArgumentError, "Pipleline stage #{proc} must be a lambda or Proc")
    elsif (proc.arity != 1)
      raise(ArgumentError, "Pipleline stage #{proc} needs to take one parameter")
    end

    TaskHandler.new do |work|
      result = proc.call(work)
      downstream.push(result) if downstream
    end    
  end
end

