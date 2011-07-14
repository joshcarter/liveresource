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
  include LiveResource::MethodProvider
  include LiveResource::MethodSender
  
  remote_accessor :upcased_color
  remote_subscription :color, :update_color
  remote_method :foo
  
  def initialize
    self.namespace = 'colors.favorite'
  end
  
  def update_color(new_color)
    self.upcased_color = new_color.upcase
  end
  
  # I know this has nothing to do with colors. Sue me. -jdc
  def foo
    'foo'
  end
end

class CompositeResourceTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end

  def test_composite_resource
    fave = FavoriteColor.new
    upcased_fave = UpcasedFavoriteColor.new
    upcased_fave.subscribe
    upcased_fave.start_method_dispatcher
    
    fave.color = 'blue'
    sleep(0.25) # Takes a moment to propogate
    assert_equal 'BLUE', upcased_fave.upcased_color
    
    assert_equal 'foo', upcased_fave.remote_send(:foo)
    
    fave.color = 'green'
    sleep(0.25) # Takes a moment to propogate
    assert_equal 'GREEN', upcased_fave.upcased_color
    
    upcased_fave.unsubscribe
    upcased_fave.stop_method_dispatcher
  end
end
