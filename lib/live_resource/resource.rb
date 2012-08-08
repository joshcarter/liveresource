module LiveResource
  module Resource
    include LiveResource::LogHelper
    include LiveResource::Common
    include LiveResource::Attribute
    include LiveResource::MethodProvider
  end
end