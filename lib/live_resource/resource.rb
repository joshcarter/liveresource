require_relative 'redis_client'
require_relative 'declarations'
require_relative 'method_dispatcher'

module LiveResource
  module Resource
    include LiveResource::LogHelper
    include LiveResource::Declarations
    include LiveResource::MethodDispatcher
  end
end