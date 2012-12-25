require_relative 'error'
require_relative 'log_helper'
require_relative 'declarations'
require_relative 'finders'
require_relative 'attributes'
require_relative 'methods'
require_relative 'methods/forward'

module LiveResource

  # Module for all Resource providers. Any instances of resources should
  # be registered with LiveResource::register. The class may also be
  # registered, if any class attributes/methods should be remotely
  # callable.
  module Resource
    include LiveResource::LogHelper
    include LiveResource::ErrorHelper
    include LiveResource::Declarations
    include LiveResource::Finders
    include LiveResource::Attributes
    include LiveResource::Methods

    # Extends resource classes with proper class methods and
    # class-level method dispatcher.
    def self.included(base)
      base.extend(LiveResource::Declarations::ClassMethods)

      # The class is also extended with attribute and method support
      # (i.e, the method dispatcher).
      base.extend(LiveResource::Attributes)
      base.extend(LiveResource::Methods)
    end

    # Create forward instruction that can be returned by a remote
    # method, instructing LiveResource to forward to a different
    # remote method instead of returing directly to the caller.
    #
    # @param [LiveResource::ResourceProxy] resource the resource to forward to
    # @param [Symbol] method the resource's method to call
    # @param params any parameters to pass with the method call
    # @return [LiveResource::RemoteMethodForward] a forward instruction, used internally by LiveResource
    def forward(resource, method, *params)
      LiveResource::RemoteMethodForward.new(resource, method, params)
    end
    
    # Create proxy describing this resource. Generally only used by the
    # resource itself; clients should use the finders (find, all, etc.)
    # instead.
    def to_proxy
      ResourceProxy.new(redis.redis_class, redis.redis_name)
    end
  end
end
