require_relative 'remote_methods/dispatcher'

module LiveResource
  module RemoteMethods
    attr_reader :dispatcher

    def start
      if @dispatcher
        @dispatcher.start
      else
        @dispatcher = RemoteMethodDispatcher.new(self)
      end
    end

    def stop
      return if @dispatcher.nil?

      @dispatcher.stop
    end

    def running?
      @dispatcher && @dispatcher.running?
    end

    # By default, all public methods of this class are remote callable.
    def remote_methods
      m = self.class.public_instance_methods

      # Subtract methods inherited from our parent(s)
      m - self.class.ancestors[1].public_instance_methods
    end
  end
end

