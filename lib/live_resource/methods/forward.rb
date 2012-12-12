module LiveResource
  class RemoteMethodForward
    attr_reader :resource, :method, :params, :next

    def initialize(resource, method, params)
      @resource = resource
      @method = method
      @params = params
      @next = nil
    end

    def continue(resource, method, *params)
      @next = self.class.new(resource, method, params)
      self
    end

    def inspect
      "#{self.class}: #{@resource} #{@method} (#{@params.length} params)"
    end
  end
end
