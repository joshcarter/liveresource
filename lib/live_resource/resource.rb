require_relative 'log_helper'
require_relative 'redis_client'
require_relative 'declarations'
require_relative 'finders'
require_relative 'method_dispatcher'

module LiveResource
  module Resource
    include LiveResource::LogHelper
    include LiveResource::Declarations
    include LiveResource::Finders
    include LiveResource::MethodDispatcher
    include LiveResource::HasRedisClient
  end
end
