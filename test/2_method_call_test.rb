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

    def swap_a_b(myclass)
      a, b = myclass.a, myclass.b
      myclass.b = a
      myclass.a = b
      myclass
    end
  end

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

    # Non-native class
    myclass = client.swap_a_b MyClass.new("a", "b")
    assert_equal "b", myclass.a
    assert_equal "a", myclass.b

    # Should have no junk left over in Redis
    assert_equal starting_keys, Redis.new.dbsize
  end

  def test_method_with_no_response
    starting_keys = Redis.new.dbsize
    client = LiveResource::any(:server)

    # Do one async call; dispatcher should auto-clean up
    client.upcase! "foobar"

    # Do a sync call afterward to make sure the first is done
    client.upcase "foobar"

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


  def test_method_call_with_future
    starting_keys = Redis.new.dbsize
    client = LiveResource::any(:server)

    value = client.slow_upcase? 'foobar'

    assert_not_nil value
    assert_equal false, value.done?

    # Wait for valid result.
    assert_equal 'FOOBAR', value.value

    # Should have no junk left over in Redis, BUT we can still get the
    # future's value as many times as we want.
    assert_equal starting_keys, Redis.new.dbsize
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

    starting_keys = Redis.new.dbsize

    assert_raise(RuntimeError) do
      value = client.upcase? "foobar"
      value.value(1)
    end

    # Should have no junk left over in Redis
    assert_equal starting_keys, Redis.new.dbsize
  end

  def test_method_completes_after_timeout
    starting_keys = Redis.new.dbsize
    client = LiveResource::any(:server)

    # Turn up log level; this test will generate an appropriate warning.
    old_level = LiveResource::RedisClient.logger.level = Logger::ERROR

    # This will fail (as above) but the server will actually complete it a second
    # later. Need to make sure server cleans up ok.
    assert_raise(RuntimeError) do
      value = client.two_second_upcase? "foobar"
      value.value(1)
    end

    sleep 2

    # Should have no junk left over in Redis
    assert_equal starting_keys, Redis.new.dbsize

    LiveResource::RedisClient.logger.level = old_level
  end
end
