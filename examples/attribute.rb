require 'rubygems'
require 'lib/live_resource'

class FavoriteColorPublisher
  include LiveResource::Attribute

  remote_writer :favorite
end

publisher = FavoriteColorPublisher.new
publisher.namespace = "color"
publisher.favorite = "blue"

class FavoriteColor
  include LiveResource::Attribute

  remote_reader :favorite
end

reader = FavoriteColor.new
reader.namespace = "color"
puts reader.favorite # --> "blue"
