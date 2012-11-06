require_relative '../test_helper'

class ProcessSupervisorTest < Test::Unit::TestCase
  def setup
    @ts = LiveResource::Supervisor::Supervisor.new
    @ew = TestEventWaiter.new
  end

  def teardown
  end

  def test_empty_supervisor_has_no_process_supervisor
    assert_nil @ts.process_supervisor
  end

  def test_add_processes
    file1 = File.expand_path("./test/supervisor/test_scripts/test1.rb")
    file2 = File.expand_path("./test/supervisor/test_scripts/test2.rb")

    # Add our two test scripts
    @ts.supervise_process("test1", file1)
    @ts.supervise_process("test2", file2)

    # We should now have a process supervisor
    ps = @ts.process_supervisor
    assert_not_nil ps

    # The process supervisor should have no running workers yet
    assert !ps.running_workers?
  end

  def test_add_directory
    dir = File.expand_path("./test/supervisor/test_scripts")

    @ts.supervise_directory("test1", dir)

    # We should now have a process supervisor
    ps = @ts.process_supervisor

    # The process supervisor should have no running workers yet
    assert !ps.running_workers?
  end

  def test_add_nonexistent_file
    # This file does not exist
    file = File.expand_path("./test/supervisor/test_scripts/__does_not_exist.rb")

    # So we should get an exception
    assert_raise(ArgumentError) { @ts.supervise_process("test", file) }
  end

  def test_add_nonexecutable_file
    # This file is not executable
    file = File.expand_path("./test/supervisor/test_scripts/__not_executable.rb")

    # So we should get an exception
    assert_raise(ArgumentError) { @ts.supervise_process("test", file) }
  end

  def test_add_nonexistent_directory
    # This directory does not exists
    dir = File.expand_path("./test/supervisor/test_scripts/__does_not_exist")

    # So we should get an exception
    assert_raise(ArgumentError) { @ts.supervise_directory("test", dir) }
  end

  def test_empty_directory
    # Make an empty directory in /tmp
    dir = "/tmp/__lr_supervisor_test_empty_#{Time.now}"
    Dir.mkdir dir

    # We should get an exception, since there are no workers to add
    assert_raise(ArgumentError) { @ts.supervise_directory("test", dir) }

    Dir.rmdir dir
  end

  def test_run_stop
    file1 = File.expand_path("./test/supervisor/test_scripts/test1.rb")

    # Add a test script. This test script simply sleeps forever.
    @ts.supervise_process("test1", file1) do |on|
      on.started { |worker| @ew.send_event :started }
      on.stopped { |worker| @ew.send_event :stopped }
    end

    @ts.run

    ps = @ts.process_supervisor

    # Wait up to 5 seconds for workers to start
    assert_equal :started, @ew.wait_for_event(5)
    assert_equal true, ps.running_workers?

    @ts.stop

    # Wait up to 5 seconds for workers to stop
    assert_equal :stopped, @ew.wait_for_event(5)
    assert_equal false, ps.running_workers?
  end

  def test_suspend
    file2 = File.expand_path("./test/supervisor/test_scripts/test2.rb")

    # Add a test script. This test scripts sleeps
    @ts.supervise_process("test2", file2, restart_limit: 2, suspend_period: 4) do |on|
      on.started { |worker| @ew.send_event :started }
      on.suspended { |worker| @ew.send_event :suspended }
      on.stopped { |worker| @ew.send_event :stopped }
    end

    @ts.run

    # Wait up to 5 seconds for workers to start
    assert_equal :started, @ew.wait_for_event(5)

    # The test script crashes immediately, but it should get restarted twice.
    2.times do
      assert_equal :started, @ew.wait_for_event(5)
    end
    
    # Now it should get suspended.
    assert_equal :suspended, @ew.wait_for_event(5)

    # The test script should eventually get restarted
    assert_equal :started, @ew.wait_for_event(10)

    @ts.stop

    # Wait up to 5 seconds for workers to stop
    loop do
      break if @ew.wait_for_event(5) != :stopped
    end
  end
end
