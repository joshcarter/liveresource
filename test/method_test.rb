require_relative 'test_helper'

# We slice, we dice, we can cut through tin cans!
class Server
  include LiveResource::Resource

  resource_class :server
  resource_name :object_id

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

  def two_second_upcase(str)
    sleep 2
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

    LiveResource::register Server.new
  end

  def teardown
    LiveResource::stop
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

  def test_synchronous_method
    starting_keys = Redis.new.dbsize
    client = LiveResource::any(:server)

    # Zero parameters
    assert_equal 42, client.meaning

    # One parameter (simple)
    assert_equal "FOOBAR", client.upcase("foobar")

    # One parameter (complex)
    assert_equal [3, 2, 1], client.reverse([1, 2, 3])

    # Two parameters
    assert_equal 3, client.add(1, 2)

    # Should have no junk left over in Redis
    assert_equal starting_keys, Redis.new.dbsize
  end

  def test_no_matching_method
    client = LiveResource::any(:server)

    assert_raise(NoMethodError) do
      client.this_is_not_a_valid_method
    end
  end

  def test_method_stress
    starting_keys = Redis.new.dbsize
    client = LiveResource::any(:server)

    100.times do
      client.upcase("foobar")
    end

    # Should have no junk left over in Redis
    assert_equal starting_keys, Redis.new.dbsize
  end


#   def test_async_wait_for_done
#     with_servers do
#       client = Client.new

#       token = client.remote_send_async(:slow_upcase, 'foobar')

#       assert_not_nil token
#       assert_equal false, client.done_with?(token)

#       # Wait for valid result.
#       assert_equal 'FOOBAR', client.wait_for_done(token)

#       # After waiting for done, resource doesn't know anything about
#       # the token anymore.
#       assert_raise(ArgumentError) do
#         client.done_with?(token)
#       end
#     end
#   end

#   # Similar test to above, but in this case we don't wait for done until
#   # after we already know the action is done.
#   def test_wait_for_done_after_done
#     with_servers do
#       # Repeat a bunch of times -- this helps catch a race
#       # condition in done_with?
#       100.times do
#         client = Client.new

#         token = client.remote_send_async(:slow_upcase, 'foobar')

#         while !client.done_with?(token)
#           Thread.pass
#         end

#         # Result should be ready for us
#         assert_equal 'FOOBAR', client.wait_for_done(token)
#       end
#     end
#   end

#   def test_method_timeout_success
#     with_servers do
#       client = Client.new

#       assert_equal "FOOBAR", client.remote_send_with_timeout(:upcase, 1, "foobar")
#     end
#   end

#   def test_method_timeout_failure
#     # No servers
#     client = Client.new

#     assert_raise(RuntimeError) do
#       client.remote_send_with_timeout(:upcase, 1, "foobar")
#     end

#     # Should have no junk left over in Redis
#     assert_equal 0, Redis.new.dbsize
#   end

#   def test_method_completes_after_timeout
#     with_servers do
#       client = Client.new

#       # This will fail (as above) but the server will actually complete it a second
#       # later. Need to make sure server cleans up ok.
#       assert_raise(RuntimeError) do
#         client.remote_send_with_timeout(:two_second_upcase, 1, "foobar")
#       end
#     end

#     # Should have no junk left over in Redis
#     assert_equal 0, Redis.new.dbsize
#   end

end
