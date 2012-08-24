require_relative 'log_helper'
require_relative 'declarations'
require_relative 'finders'
require_relative 'remote_methods'

module LiveResource
  module Resource
    include LiveResource::LogHelper
    include LiveResource::Declarations
    include LiveResource::Finders
    include LiveResource::RemoteMethods

    def self.included(base)
      base.extend(LiveResource::RemoteMethods)
      base.extend(LiveResource::Declarations::ClassMethods)
      base.extend(LiveResource::RemoteMethods::ClassMethods)
    end
  end
end
