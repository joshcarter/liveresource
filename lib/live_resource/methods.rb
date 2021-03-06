require_relative 'methods/dispatcher'

module LiveResource
  module Methods
    attr_reader :dispatcher

    # Register this resource with LiveResource.
    # When resources are registered their basic state is placed into Redis,
    # however they may not be used until they have been started.
    def register(*instance_init_params)
      redis.register(self, *instance_init_params)
      self
    end

    # Start the method dispatcher for this resource. On return, the
    # resource will be visible to finders (.all(), etc.)
    # and remote methods may be called.
    def start
      unless redis.registered?
        raise RuntimeError, "Resource must be registerd before it can be started."
      end

      on_resource_start

      if defined? @dispatcher and @dispatcher
        @dispatcher.start
      else
        @dispatcher = RemoteMethodDispatcher.new(self)
      end

      @dispatcher.wait_for_running
      self
    end

    def stop
      return if not defined? @dispatcher

      @dispatcher.stop
      on_resource_stop
      self
    end

    def running?
      @dispatcher && @dispatcher.running?
    end

    def delete
      return if not defined? @dispatcher

      @dispatcher.delete
      self
    end

    def deleted?
      @dispatcher && @dispatcher.deleted?
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
