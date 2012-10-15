require_relative 'supervisor/declarations'

module LiveResource
  module Supervisor
    def self.included(base)
      base.extend(LiveResource::Supervisor::Declarations::ClassMethods)
    end
  end
end
