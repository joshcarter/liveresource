require_relative 'log_helper'
require_relative 'redis_client'
require_relative 'declarations'
require_relative 'finders'
require_relative 'remote_methods'

module LiveResource
  module Resource
    include LiveResource::LogHelper
    include LiveResource::Declarations
    include LiveResource::Finders
    include LiveResource::RemoteMethods
    include LiveResource::RedisClientExtensions
  end
end
