require 'rubygems'
require 'lib/live_resource'

class FavoriteColorPublisher
  include LiveResource::Attribute

  remote_writer :favorite
end

publisher = FavoriteColorPublisher.new
publisher.namespace = "color"
publisher.favorite = "blue"

class FavoriteColorSubscriber
  include LiveResource::Subscriber

  remote_subscription :favorite

  def favorite(new_favorite)
    puts "Publisher changed its favorite to #{new_favorite}"
  end
end

subscriber = FavoriteColorSubscriber.new
subscriber.namespace = "color"
subscriber.subscribe # Spawns thread

# Publisher object from the "Attribute" section above.
publisher.favorite = "red"
publisher.favorite = "green"

subscriber.unsubscribe
