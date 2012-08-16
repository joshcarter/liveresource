require File.join(File.dirname(__FILE__), 'test_helper')

class Sender
  include LiveResource::MethodSender
  
  def initialize
    self.namespace = 'test'
  end
end

class MethodSenderTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end
  
  def test_send_sequence
    sender = Sender.new
    rs = sender.redis_space.clone
    
    # Put method on waiting queue
    token = sender.remote_send_async(:method, 1, 2, 3)
    assert_not_nil token
    assert_equal false, sender.done_with?(token)
    assert_equal :method, rs.method_get(token, :method)
    assert_equal [1, 2, 3], rs.method_get(token, :params)
    
    # Now play provider, move token from waiting to in-progress.
    token2 = rs.method_wait
    assert_equal token2, token
    assert_equal false, sender.done_with?(token)
    
    # Set and fetch result
    rs.result_set token, 42
    rs.method_done token
    assert_equal true, sender.done_with?(token)
    assert_equal 42, sender.wait_for_done(token)
    
    # No crud left around in Redis
    assert_equal 0, Redis.new.dbsize
  end
end