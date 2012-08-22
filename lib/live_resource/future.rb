module LiveResource
  # Returned from async method calls, in order to later get a method's
  # return value.
  class Future
    def initialize(proxy, token)
      @proxy = proxy
      @token = token
      @value = nil
    end

    def value(timeout = 0)
      if @value.nil?
        @value = @proxy.wait_for_done(@token, timeout)
      end

      @value
    end

    def done?
      if @value.nil?
        @proxy.done_with? @token
      else
        true
      end
    end
  end
end
