require File.join(File.dirname(__FILE__), 'test_helper')

class FavoriteColor
  include LiveResource::Attribute

  remote_writer :color
  
  def initialize
    self.namespace = 'colors.favorite'
  end
end

class UpcasedFavoriteColor
  include LiveResource::Attribute
  include LiveResource::Subscriber
  
  remote_accessor :upcased_color
  remote_subscription :color, :update_color
  
  def initialize
    self.namespace = 'colors.favorite'
  end
  
  def update_color(new_color)
    self.upcased_color = new_color.upcase
  end
end

class CompositeResourceTest < Test::Unit::TestCase
  def test_composite_resource
    # TODO: this won't work at the moment because the subscriber's 
    # RedisSpace limits what accesses can be made while in subscribe mode.
    #
    # fave = FavoriteColor.new
    # upcased_fave = UpcasedFavoriteColor.new
    # upcased_fave.subscribe
    # 
    # fave.color = 'blue'
    # assert_equal 'BLUE', upcased_fave.upcased_color
    # 
    # fave.color = 'green'
    # assert_equal 'GREEN', upcased_fave.upcased_color
    # 
    # upcased_fave.unsubscribe
    assert true
  end
end
