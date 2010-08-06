require 'task_handler'

class Pipeline
  # Pipeline stages should be ordered from upstream to downstream
  def initialize(*stages)
    # Verify these are objects that will work in a pipeline
    stages.each do |s|
      next if (s.class == Proc)
      raise(ArgumentError, "Pipleline stage #{s} does not respond to push") unless s.respond_to?(:push)
      raise(ArgumentError, "Pipleline stage #{s} does not respond to pop") unless s.respond_to?(:pop)
    end

    @stages = [Queue.new] + stages

    (0...stages-1).to_a.reverse.each do |i|
      stage1 = @stages[i]      # current stage
      stage2 = @stages[i + 1]  # downstream stage

      # If final stage is a proc, convert it to a unary task handler
      if (stage2.class == Proc)
        stage2 = TaskHandler.new { stage2 }
        @stages[i + 1] = stage2
      end
    
      if (stage1.class == Proc)
        @stages[i] = TaskHandler.new do |work|
          stage2.push stage1.call(work)
        end
      else
        @stages[i] = TaskHandler.new do
          stage2.push stage2.pop
        end
      end
    end


    stages.map_with_index do |stage, i|


      if (i != stages.length - 1)
        next_stage = 

      if (stage.class == Proc)
        TaskHandler.new { |proc| next_stage.push proc.call }
      else
        

next_stage.push stage.pop }


  end

  def push(work)
    @stages.first.push work
  end
  alias :<< :push

  def stop
    @stages.each { |s| s.stop if s.respond_to?(:stop) }
  end
end

