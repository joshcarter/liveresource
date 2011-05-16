require File.join(File.dirname(__FILE__), 'test_helper')

class Client
  include LiveResource::MethodSender

  def initialize
    self.namespace = "test"
  end
end

# TODO: tests involving proxy
class Proxy
  include LiveResource::MethodProvider
  include LiveResource::MethodSender

  remote_method :proxied_upcase

  def initialize
    self.namespace = "test"
  end

  # Just does a syncronous send to another object, returns the result.
  def proxied_upcase
    remote_send(:upcase)
  end
end

class Server
  include LiveResource::MethodProvider
  
  # We slice, we dice, we can cut through tin cans!
  remote_method :meaning, :upcase, :slow_upcase
  remote_method :add, :reverse
  
  def initialize
    self.namespace = "test"
  end
  
  def meaning
    42
  end
  
  def upcase(str)
    str.upcase
  end
  
  def slow_upcase(str)
    10.times { Thread.pass }
    str.upcase
  end
  
  def add(a, b)
    a + b
  end
  
  def reverse(arr)
    arr.reverse
  end
end

class MethodTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end
  
  def test_start_stop_dispatcher
    server = Server.new
    
    assert_not_nil server.start_method_dispatcher
    server.stop_method_dispatcher

    assert_equal nil, server.dispatcher_thread
  end

  # TODO: some test like this
  #
  # def test_method_done
  #   rs = LiveResource::RedisSpace.new('test')
  # 
  #   assert_raise(ArgumentError) do
  #     rs.method_done? '1' # Doesn't exist yet
  #   end
  # 
  #   rs.method_push '1'
  #   assert_equal false, rs.method_done?('1')
  # 
  #   rs.method_wait
  #   assert_equal false, rs.method_done?('1')
  # 
  #   rs.result_set '1', 42
  #   rs.method_done '1'
  #   assert_equal true, rs.method_done?('1')
  # end
  
  def with_servers(&block)
    server = Server.new
    server.start_method_dispatcher
    
    # proxy = Proxy.new
    # proxy.start_method_dispatcher

    begin
      block.call
    ensure
      # proxy.stop_method_dispatcher
      server.stop_method_dispatcher
    end
  end
  
  def test_synchronous_method
    with_servers do
      client = Client.new
    
      # Zero parameters
      assert_equal 42, client.remote_send(:meaning)
    
      # One parameter (simple)
      assert_equal "FOOBAR", client.remote_send(:upcase, "foobar")
    
      # One parameter (complex)
      assert_equal [3, 2, 1], client.remote_send(:reverse, [1, 2, 3])
    
      # Two parameters
      assert_equal 3, client.remote_send(:add, 1, 2)
    end
    
    # Should have no junk left over in Redis
    assert_equal 0, Redis.new.dbsize
  end
  
  def test_async_wait_for_done
    with_servers do
      client = Client.new
      
      token = client.remote_send_async(:slow_upcase, 'foobar')
      
      assert_not_nil token
      assert_equal false, client.done_with?(token)

      # Wait for valid result.
      assert_equal 'FOOBAR', client.wait_for_done(token)

      # After waiting for done, resource doesn't know anything about
      # the token anymore.
      assert_raise(ArgumentError) do
        client.done_with?(token)
      end
    end
  end
  
  # Similar test to above, but in this case we don't wait for done until
  # after we already know the action is done.
  def test_wait_for_done_after_done
    with_servers do
      client = Client.new
      
      token = client.remote_send_async(:slow_upcase, 'foobar')
      
      while !client.done_with?(token)
        Thread.pass
      end
      
      # Result should be ready for us
      assert_equal 'FOOBAR', client.wait_for_done(token)
    end
  end
  
  def test_done_with_invalid_token
    with_servers do
      client = Client.new
      
      assert_raise(ArgumentError) do
        client.done_with?('this is not a valid token')
      end      
    end
  end
  
  def test_no_matching_method
    with_servers do
      client = Client.new
      
      assert_raise(NoMethodError) do
        client.remote_send(:this_is_not_a_valid_method)
      end
    end
  end

  def test_method_stress
    with_servers do
      client = Client.new
      
      100.times do
        client.remote_send(:upcase, "foobar")
      end
    end
    
    # Should have no junk left over in Redis
    assert_equal 0, Redis.new.dbsize
  end
end
