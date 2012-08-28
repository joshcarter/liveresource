require_relative 'log_helper'
require_relative 'declarations'
require_relative 'finders'
require_relative 'attributes'
require_relative 'methods'

module LiveResource

  # Module for all Resource providers. Any instances of resources should
  # be registered with LiveResource::register. The class may also be
  # registered, if any class attributes/methods should be remotely
  # callable.
  module Resource
    include LiveResource::LogHelper
    include LiveResource::Declarations
    include LiveResource::Finders
    include LiveResource::Attributes
    include LiveResource::Methods

    def self.included(base)
      base.extend(LiveResource::Declarations::ClassMethods)

      # The class is also extended with attribute and method support
      # (i.e, the method dispatcher).
      base.extend(LiveResource::Attributes)
      base.extend(LiveResource::Methods)
    end
  end
end
