require_relative '../test_helper'

class ResourceMaterializeTest < Test::Unit::TestCase
  def setup
    flush_redis

    LiveResource::RedisClient.logger.level = Logger::INFO
    @redis = LiveResource::RedisClient.new(:test_materialize, :foo)
    @ew = TestEventWaiter.new
    @ew_log = false
    @pids = []

    # Subscribe to the instance channel for this resource to
    # get events when resources are created/started.
    Thread.new do
      LiveResource::RedisClient.redis.subscribe(@redis.instance_channel) do |on|
        on.message do |channel, msg|
          @ew.send_event msg
        end
      end
    end
  end

  def teardown
    # Stop any supervisors that are running in separate processes.
    @pids.each do |pid|
      Process.kill "TERM", pid
      Process.waitpid pid
    end
  end

  def test_instance_materialization
    # Create 3 supervisor processes and have them all supervise materialize resource
    created = false
    3.times do
      @pids << Process.fork do
        exec File.expand_path("./test/supervisor/test_resources/materialize.rb")
        exit
      end

      if !created
        assert_equal "class.test_materialize.created", @ew.wait_for_event(5)
        created = true
      end

      # Class resource will be started 3 times
      assert_equal "class.test_materialize.started", @ew.wait_for_event(5)
    end

    # Create an instance
    LiveResource::find(:test_materialize).new("foo", 13)

    # Instance resource will be created just once
    assert_equal "test_materialize.foo.created", @ew.wait_for_event(5)

    # Instance resource will be started 3 times
    3.times do
      msg = @ew.wait_for_event(5)
      assert_equal "test_materialize.foo.started", msg
    end

    # Check that there are 3 instances in Redis
    assert_equal 3, @redis.num_instances

    # Check that we can get a proxy to the resource
    assert_not_nil LiveResource::find(:test_materialize, :foo)
  end

  def test_instance_materialization_on_start
    # Create a supervisor
    @pids << Process.fork do
      exec File.expand_path("./test/supervisor/test_resources/materialize.rb")
      exit
    end

    # Class resource started/created
    assert_equal "class.test_materialize.created", @ew.wait_for_event(5)
    assert_equal "class.test_materialize.started", @ew.wait_for_event(5)

    @ew_log = true

    # Create some instances
    cr = LiveResource::find(:test_materialize)
    names = ["foo", "bar", "baz"]
    names.each_with_index do |n, i|
      cr.new(n, i)
      # Instance resource will be created/started
      assert_equal "test_materialize.#{n}.created", @ew.wait_for_event(5)
      assert_equal "test_materialize.#{n}.started", @ew.wait_for_event(5)
    end

    # Create another supervisor
    @pids << Process.fork do
      exec File.expand_path("./test/supervisor/test_resources/materialize.rb")
      exit
    end

    # The new supervisor should start its own copy of the existing resources (class and instances)
    assert_equal "class.test_materialize.started", @ew.wait_for_event(5)
    names.each do |n|
      assert_equal "test_materialize.#{n}.started", @ew.wait_for_event(5)
    end
  end

  def test_instance_initialization_uses_stored_params
    # Create a supervisor
    @pids << Process.fork do
      exec File.expand_path("./test/supervisor/test_resources/materialize.rb")
      exit
    end

    # Class resource started/created
    assert_equal "class.test_materialize.created", @ew.wait_for_event(5)
    assert_equal "class.test_materialize.started", @ew.wait_for_event(5)

    # Create an instance
    foo = LiveResource::find(:test_materialize).new("foo", 13)

    # Instance resource will be created/started
    assert_equal "test_materialize.foo.created", @ew.wait_for_event(5)
    assert_equal "test_materialize.foo.started", @ew.wait_for_event(5)

    # Change the instance "value" attribute
    assert_equal 13, foo.value
    foo.value = 23
    assert_equal 23, foo.value

    # Create another supervisor and wait for it to start its resources
    @pids << Process.fork do
      exec File.expand_path("./test/supervisor/test_resources/materialize.rb")
      exit
    end

    assert_equal "class.test_materialize.started", @ew.wait_for_event(5)
    assert_equal "test_materialize.foo.started", @ew.wait_for_event(5)

    # Since we store the original initialization params and the constructor always overwrites
    # the "value" attribute, it should be reset to the original value when the new supervisor
    # creates its copy of the instance.
    assert_equal 13, foo.value
  end
end
