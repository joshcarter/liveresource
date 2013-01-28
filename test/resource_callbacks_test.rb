require_relative 'test_helper'

class ResourceCallbacksTest < Test::Unit::TestCase
  class Class1
    include LiveResource::Resource

    resource_name :object_id
    resource_class :class_1

    remote_reader :started

    on_resource_start :start_cb
    on_resource_stop :stop_cb

    def initialize
      remote_attribute_writenx :started, false
    end

    private

    # Make start/stop callbacks private so they won't be remote-callable
    def start_cb
      remote_attribute_write :started, true
    end

    def stop_cb
      remote_attribute_write :started, false
    end
  end

  def setup
    Redis.new.flushall

    LiveResource::register(Class1).start
  end

  def teardown
    LiveResource::shutdown
  end

  # New resource instances are auto-started, so their started callback
  # should have already executed by the time we get our handle
  def test_started
    r = LiveResource::find(:class_1).new

    assert_equal true, r.started
  end

  # When the resource is stopped, its stopped callback should be executed. Note
  # we can still read attributes of a stopped resource, since that merely checks
  # state in redis
  def test_stopped
    r = LiveResource::find(:class_1).new

    assert_equal true, r.started

    LiveResource::stop

    assert_equal false, r.started
  end
end
