require 'rubygems'
require 'lib/live_resource'

class FavoriteColorPublisher
  include LiveResource::Attribute

  remote_accessor :favorite

  # Update favorite color to anything except the currently-published
  # favorite.
  def update_favorite
    colors = ['red', 'blue', 'green']

    remote_modify(:favorite) do |current_favorite|
      colors.delete(current_favorite)

      # Value of block will become the new value of the attribute.
      colors.shuffle.first
    end
  end
end

color = FavoriteColorPublisher.new
color.namespace = "color"
color.favorite = "blue"

10.times do
  puts "Current fave: #{color.favorite}"
  color.update_favorite
end
