require_relative '../test_helper'

class ResourceSupervisorTest < Test::Unit::TestCase
  class Test1
    include LiveResource::Resource

    resource_class :test1
    resource_name :name

    remote_accessor :name

    def initialize(name)
      # Only overwrite our name if it doesn't exist yet
      remote_attribute_writenx(:name, name)
    end
  end

  def setup
    flush_redis

    LiveResource::RedisClient.logger.level = Logger::INFO

    @ts = LiveResource::Supervisor::Supervisor.new
    @ew = TestEventWaiter.new
  end

  def teardown
  end

  def test_empty_supervisor_has_no_resource_supervisor
    assert_nil @ts.resource_supervisor
  end

  def test_add_resources
    @ts.supervise_resource Test1

    rs = @ts.resource_supervisor
    assert_not_nil rs

    assert !rs.running_workers?
  end

  def test_run_stop
    @ts.supervise_resource Test1 do |on|
      on.started { |worker| @ew.send_event :started }
      on.stopped { |worker| @ew.send_event :stopped }
    end

    @ts.run

    rs = @ts.resource_supervisor

    # Wait up to 5 seconds for class resource to start
    assert_equal :started, @ew.wait_for_event(5)
    assert rs.running_workers?

    # Make sure we can get a proxy to the class resource
    assert_not_nil LiveResource::find(:test1)

    @ts.stop

    # Wait for up to 5 seconds for class resource to stop
    assert_equal :stopped, @ew.wait_for_event(5)
    assert !rs.running_workers?

    # No proxy available anymore
    assert_nil LiveResource::find(:test1)
  end

  def test_create_instances
    @ts.supervise_resource Test1 do |on|
      on.started { |worker| @ew.send_event :started }
      on.stopped { |worker| @ew.send_event :stopped }
    end

    @ts.run

    rs = @ts.resource_supervisor

    # Wait up to 5 seconds for class resource to start
    assert_equal :started, @ew.wait_for_event(5)
    assert rs.running_workers?

    # Create a new instance
    LiveResource::find(:test1).new("foo")

    # Should get a started event when the new instance starts
    assert_equal :started, @ew.wait_for_event(5)

    # Make sure we can find the instance
    assert_not_nil LiveResource::find(:test1, :foo)

    @ts.stop

    # Class and instance should stop
    2.times { assert_equal :stopped, @ew.wait_for_event(5) }

    # No proxies available anymore
    assert_nil LiveResource::find(:test1)
    assert_nil LiveResource::find(:test1, :foo)
  end

  def test_resource_name_filter
    # Only monitor resources whose names match the regex given by the name_filter option.
    @ts.supervise_resource(Test1, name_filter: /^f.*/)  do |on|
      on.started { |worker| @ew.send_event :started }
      on.stopped { |worker| @ew.send_event :stopped }
    end

    @ts.run

    rs = @ts.resource_supervisor

    # Wait up to 5 seconds for class resource to start
    assert_equal :started, @ew.wait_for_event(5)

    # Create a new instance with a name that matches the filter.
    cr = LiveResource::find(:test1)
    cr.new("foo")

    # Should get started events when the new instance starts
    assert_equal :started, @ew.wait_for_event(5)

    # Make sure we can find the instance
    assert_not_nil LiveResource::find(:test1, :foo)

    # The resource supervisor should have workers for the class/instance resources
    rs = @ts.resource_supervisor
    assert_equal 2, rs.num_workers

    # Create an instance which doesn't match the name filter.
    cr.new("bar")

    # Should be no pending events
    assert_equal true, @ew.empty?

    # Should be no proxy
    assert_nil LiveResource::find(:test1, :bar)

    # Resource supervisor should still only have 2 workers.
    assert_equal 2, rs.num_workers

    @ts.stop

    # Class and instance should stop
    2.times { assert_equal :stopped, @ew.wait_for_event(5) }
  end

  def test_delete_instance
    @ts.supervise_resource Test1 do |on|
      on.started { |worker| @ew.send_event :started }
      on.stopped { |worker| @ew.send_event :stopped }
      on.deleted { |worker| @ew.send_event :deleted }
    end

    @ts.run

    rs = @ts.resource_supervisor

    # Wait up to 5 seconds for class resource to start
    assert_equal :started, @ew.wait_for_event(5)
    assert rs.running_workers?

    # Create a new instance
    LiveResource::find(:test1).new("foo")

    # Should get a started event when the new instance starts
    assert_equal :started, @ew.wait_for_event(5)

    # Supervisor should have 2 workers; one for class resource, one for instance
    assert_equal 2, rs.num_workers

    # Make sure we can find the instance
    foo = LiveResource::find(:test1, :foo)
    assert_not_nil foo

    # Delete the instance
    foo.delete

    # Should get a deleted event when the instance deletes
    assert_equal :deleted, @ew.wait_for_event(5)

    # Should only have one worker now (for the class resource)
    assert_equal 1, rs.num_workers

    # No proxies should be available for foo
    assert_nil LiveResource::find(:test1, :foo)

    @ts.stop

    # Class should stop
    assert_equal :stopped, @ew.wait_for_event(5)
  end
end
