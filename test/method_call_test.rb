require 'set'
require 'thread'
require_relative 'test_helper'

class MethodTest < Test::Unit::TestCase
  class MyClass
    attr_accessor :a, :b

    def initialize(a, b)
      @a = a
      @b = b
    end
  end

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

    def add(a, b)
      a + b
    end

    def reverse(arr)
      arr.reverse
    end

    def swap_a_b(myclass)
      a, b = myclass.a, myclass.b
      myclass.b = a
      myclass.a = b
      myclass
    end

    def delayed_upcase(str)
      # So the caller can control when this method completes
      delayed_upcase_queue.pop
      str.upcase
    end

    def delayed_upcase_queue
      if defined?(@delayed_upcase_queue)
        @delayed_upcase_queue
      else
        @delayed_upcase_queue = Queue.new
      end
    end
  end

  def setup
    flush_redis

    @server = Server.new

    # The methods_in_progress list is cleaned up in the resource instance
    # thread after the result has been sent.  Need to wait for "method_done"
    # to be called before checking the Redis keys.
    @method_done_queue = Queue.new
    class << @server.redis
      def method_done_queue=(queue)
        @method_done_queue = queue
      end
      alias original_method_done method_done
      def method_done(token)
        original_method_done(token)
        @method_done_queue << token
      end
    end
    @server.redis.method_done_queue = @method_done_queue
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
    starting_keys = Set.new(redis_keys)
    client = LiveResource::any(:server)

    # Zero parameters
    assert_equal 42, client.meaning

    # One parameter (simple)
    assert_equal "FOOBAR", client.upcase("foobar")

    # One parameter (complex)
    assert_equal [3, 2, 1], client.reverse([1, 2, 3])

    # Two parameters
    assert_equal 3, client.add(1, 2)

    # Non-native class
    myclass = client.swap_a_b MyClass.new("a", "b")
    assert_equal "b", myclass.a
    assert_equal "a", myclass.b

    # One for each method call
    5.times { @method_done_queue.pop }

    # Should have no junk left over in Redis
    ending_keys = Set.new(redis_keys)
    assert_equal starting_keys, ending_keys
  end

  def test_method_with_no_response
    starting_keys = Set.new(redis_keys)
    client = LiveResource::any(:server)

    # Do one async call; dispatcher should auto-clean up
    client.upcase! "foobar"

    # Do a sync call afterward to make sure the first is done
    client.upcase "foobar"

    # One for each method call
    2.times { @method_done_queue.pop }

    ending_keys = Set.new(redis_keys)
    assert_equal starting_keys, ending_keys
  end

  def test_no_matching_method
    client = LiveResource::any(:server)

    assert_raise(NoMethodError) do
      client.this_is_not_a_valid_method
    end
  end

  def test_method_stress
    starting_keys = Set.new(redis_keys)
    client = LiveResource::any(:server)

    100.times do
      client.upcase("foobar")
      @method_done_queue.pop
    end

    # Should have no junk left over in Redis
    ending_keys = Set.new(redis_keys)
    assert_equal starting_keys, ending_keys
  end

  def test_method_call_with_future
    starting_keys = Set.new(redis_keys)
    client = LiveResource::any(:server)

    value = client.slow_upcase? 'foobar'

    assert_not_nil value
    assert_equal false, value.done?

    # Wait for valid result.
    assert_equal 'FOOBAR', value.value

    @method_done_queue.pop

    # Should have no junk left over in Redis, BUT we can still get the
    # future's value as many times as we want.
    ending_keys = Set.new(redis_keys)
    assert_equal starting_keys, ending_keys
    assert_equal 'FOOBAR', value.value
  end

  # Similar test to above, but in this case we don't wait for done until
  # after we already know the action is done.
  def test_wait_for_done_after_done
    client = LiveResource::any(:server)

    # Repeat a bunch of times -- this helps catch a race
    # condition in done_with?
    100.times do
      value = client.slow_upcase? 'foobar'

      while !value.done?
        Thread.pass
      end

      # Result should be ready for us
      assert_equal 'FOOBAR', value.value
    end
  end

  def test_method_timeout_success
    client = LiveResource::any(:server)
    value = client.upcase? "foobar"

    assert_equal "FOOBAR", value.value(1)
  end

  def test_method_timeout_failure
    client = LiveResource::any(:server)

    LiveResource::stop # No servers

    starting_keys = Set.new(redis_keys)

    assert_raise(RuntimeError) do
      value = client.upcase? "foobar"
      value.value(1)
    end

    @method_done_queue.pop

    # Should have no junk left over in Redis
    ending_keys = Set.new(redis_keys)
    assert_equal starting_keys, ending_keys
  end

  def test_method_completes_after_timeout
    starting_keys = Set.new(redis_keys)
    client = LiveResource::any(:server)

    # Turn up log level; this test will generate an appropriate warning.
    old_level = LiveResource::RedisClient.logger.level = Logger::ERROR

    method_cleanup_queue = Queue.new
    client_redis = client.instance_variable_get(:@redis)
    class << client_redis
      def method_cleanup_queue=(queue)
        @method_cleanup_queue = queue
      end
      alias original_method_cleanup method_cleanup
      def method_cleanup(token)
        original_method_cleanup(token)
        @method_cleanup_queue << token
      end
    end
    client_redis.method_cleanup_queue = method_cleanup_queue 

    # This will fail (as above) but the server will actually complete it when
    # we signal it to finish later. Need to make sure server cleans up ok.
    assert_raise(RuntimeError) do
      value = client.delayed_upcase? "foobar"
      value.value(1)
    end

    @server.delayed_upcase_queue << "ok to finish delayed_upcase_queue"
    @method_done_queue.pop
    method_cleanup_queue.pop

    # Should have no junk left over in Redis
    ending_keys = Set.new(redis_keys)
    assert_equal starting_keys, ending_keys

    LiveResource::RedisClient.logger.level = old_level
  end
end
