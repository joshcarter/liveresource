module LiveResource
  # Returned from async method calls, in order to later get a method's
  # return value.
  class Future
    def initialize(proxy, method)
      @proxy = proxy
      @method = method
      @value = nil
    end

    def value(timeout = 0)
      if @value.nil?
        @value = @proxy.wait_for_done(@method, timeout)
      end

      @value
    end

    def done?
      if @value.nil?
        @proxy.done_with? @method
      else
        true
      end
    end
  end
end
