require 'live_resource'
require 'test/unit'
require 'thread'
require 'yaml'

Thread.abort_on_exception = true

class SampleWorker < LiveResource::Worker
  remote_method :meaning, :upcase, :delayed_upcase, :add, :reverse

  def meaning
    42
  end
  
  def upcase(str)
    str.upcase
  end
  
  def delayed_upcase(str)
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


class WorkerTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
    @trace = false
  end
  
  def trace(s)
    puts("- #{s}") if @trace
  end
  
  def with_worker(name)
    resource = LiveResource.new(name)
    resource.worker = SampleWorker.new(resource)

    begin
      yield
    ensure
      resource.stop_worker
    end
  end

  def test_async_wait_for_done
    with_worker('test_wait_for_done') do
      resource = LiveResource.new('test_wait_for_done')
      
      token = resource.async_action(:delayed_upcase, 'foobar')
      
      assert_not_nil token
      assert_equal false, resource.done_with?(token)

      # Wait for valid result.
      assert_equal 'FOOBAR', resource.wait_for_done(token)

      # After waiting for done, resource doesn't know anything about
      # the token anymore.
      assert_raise(ArgumentError) do
        resource.done_with?(:token)
      end
    end
  end
  
  # Similar test to above, but in this case we don't wait for done until
  # after we already know the action is done.
  def test_wait_for_done_after_done
    with_worker('test_wait_for_done_after_done') do
      resource = LiveResource.new('test_wait_for_done_after_done')
      
      token = resource.async_action(:delayed_upcase, 'foobar')
      
      while !resource.done_with?(token)
        Thread.pass
      end
      
      # Result should be ready for us
      assert_equal 'FOOBAR', resource.wait_for_done(token)
    end
  end

  def test_synchronous_action
    with_worker('test_synchronous_action') do
      resource = LiveResource.new('test_synchronous_action')

      # Zero parameters
      assert_equal 42, resource.action(:meaning)

      # One parameter (simple)
      assert_equal "FOOBAR", resource.action(:upcase, "foobar")

      # One parameter (complex)
      assert_equal [3, 2, 1], resource.action(:reverse, [1, 2, 3])

      # Two parameters
      assert_equal 3, resource.action(:add, 1, 2)
    end
    
    # Should have no junk left over in Redis
    assert_equal nil, Redis.new.info["db0"]   # TODO: better way to check for keys
  end

  def test_done_with_invalid_token
    with_worker('test_done_with_invalid_token') do
      resource = LiveResource.new('test_done_with_invalid_token')
      
      assert_raise(ArgumentError) do
        resource.done_with?('not a valid token')
      end      
    end
  end
  
  def test_no_matching_action
    with_worker('test_no_matching_action') do
      resource = LiveResource.new('test_no_matching_action')
      
      assert_raise(NoMethodError) do
        resource.action(:invalid_method)
      end
    end
  end

  def test_action_stress
    with_worker("foo") do
      resource = LiveResource.new("foo")
      
      100.times do
        resource.action(:upcase, "foobar")
      end
    end
    
    # Should have no junk left over in Redis
    assert_equal nil, Redis.new.info["db0"]
  end
end
