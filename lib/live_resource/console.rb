require 'irb'

module IRB
  @@settings = {}

  # This is very similar to IRB.start, with a few modifications for
  # exiting and re-entering the console.
  def self.start_session(binding)
    unless @@settings[:workspace]
      IRB.setup nil
      @@settings[:workspace] = WorkSpace.new(binding)
    end
    
    irb = Irb.new @@settings[:workspace]

    @CONF[:IRB_RC].call(irb.context) if @CONF[:IRB_RC]
    @CONF[:MAIN_CONTEXT] = irb.context

    @@settings[:sigint_handler] = trap("SIGINT") do
      irb.signal_handle
    end

    begin
      catch(:IRB_EXIT) do
        irb.eval_input
      end
    ensure
      IRB.irb_at_exit
      
      # Restore prior signal handler
      trap("SIGINT", @@settings[:sigint_handler])
    end
  end
end

module LiveResource
  class Console
    # Open a IRB session within the process, pausing all method dispatchers.
    # This allows a developer to inspect/tinker with running resources.
    def self.start
      # TODO: replace these hokey puts with some kind of generic box printer; allow a more
      # complete menu here.
      puts "============================ LiveResource Console ============================"
      puts "= All resources in this process are paused, type 'exit' or CTRL-D to resume, ="
      puts "= type 'stop' to shut down the process.                                      ="
      puts "=============================================================================="
      
      IRB.start_session(Kernel.binding)

      puts "============================= Resuming Resources ============================="
    end
    
    # Console command: completely exit the process.
    def self.stop
      puts "================================ Stopping... ================================="
      
      raise SystemExit.new(0)
    end
    
    # Console command: list running resources.
    def self.list
      puts "Resources in this process:"
      LiveResource::class_variable_get(:@@resources).each do |r|
        puts "- #{r.resource_class}: #{r.resource_name}"
      end
      nil
    end

    # TODO: more commands here to get into the state of the paused resources.
  end
end
