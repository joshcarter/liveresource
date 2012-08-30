require_relative 'method'

module LiveResource
  def self.forward(resource, method, *params)
    RemoteMethodForward.new(resource, method, params)
  end

  class RemoteMethodForward

  end
end
