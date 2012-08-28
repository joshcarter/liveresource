require_relative 'methods/dispatcher'

module LiveResource
  module Methods
    attr_reader :dispatcher

    # Start the method dispatcher for this resource. On return, the
    # resource will be visible to finders (.all(), etc.)
    # and remote methods may be called.
    def start
      if @dispatcher
        @dispatcher.start
      else
        @dispatcher = RemoteMethodDispatcher.new(self)
      end

      @dispatcher.wait_for_running
      self
    end

    def stop
      return if @dispatcher.nil?

      @dispatcher.stop
      self
    end

    def running?
      @dispatcher && @dispatcher.running?
    end

    def remote_methods
      if self.is_a? Class
        remote_singleton_methods
      else
        self.class.remote_instance_methods
      end
    end
  end
end

