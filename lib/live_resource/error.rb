module LiveResource
  module Error; end
  
  # Error connecting to or interacting with Redis.
  module RedisError; end

  # Error accessing a resource's methods or attributes
  module ResourceApiError; end
  
  module ErrorHelper
    # Run a block of code and tag any exceptions with LR::Error. Clients
    # may rescue either the base error or LiveResource::Error.
    def tag_errors(tag = LiveResource::Error)
      yield
    rescue Exception => error
      error.extend(LiveResource::Error)
      error.extend(tag) unless (tag == LiveResource::Error)
      raise
    end
  end
end
