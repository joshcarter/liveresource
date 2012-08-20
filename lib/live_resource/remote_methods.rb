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
  end
end

