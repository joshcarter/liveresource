require_relative '../test_helper'

class TestClass < Test::Unit::TestCase
  class TestSupervisor
    include LiveResource::Supervisor

    def initialize(name)
      @name = name
    end

  end

  def setup
    @ts = LiveResource::Supervisor::Supervisor.new
    @q = Queue.new
  end

  def teardown
  end

  def send_event(event)
    @q.push event
  end

  def wait_for_event(timeout=0)
    if timeout == 0
      event = @q.pop
    else
      timeout.times do
        begin
          break if event = @q.pop(true)
        rescue ThreadError
          sleep 1
        end
      end
    end
    event
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

    # The process supervisor should have two workers
    assert_equal ps.num_workers, 2

    # But all the workers should still be stopped, since we haven't started them yet
    assert !ps.running_workers?
  end

  def test_add_directory
    dir = File.expand_path("./test/supervisor/test_scripts")

    @ts.supervise_directory("tes1", dir)

    # The process supervisor should have two workers
    # Note, there are actually 3 script files in the directory, but
    # only two workers should be added, since the 3rd file is not
    # executable
    ps = @ts.process_supervisor
    assert_equal ps.num_workers, 2

    # But all the workers should still be stopped
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
    @ts.supervise_process("test1", file1) do |worker, event|
      send_event event
    end

    @ts.run

    ps = @ts.process_supervisor

    # Wait up to 5 seconds for workers to start
    event = wait_for_event 5
    assert_equal :started, event
    assert_equal true, ps.running_workers?

    @ts.stop

    # Wait up to 5 seconds for workers to stop
    event = wait_for_event 5
    assert_equal :stopped, event
    assert_equal false, ps.running_workers?
  end

  def test_suspend
    file2 = File.expand_path("./test/supervisor/test_scripts/test2.rb")

    # Add a test script. This test scripts sleeps
    @ts.supervise_process("test2", file2, restart_limit: 2, suspend_period: 4) do |worker, event|
      send_event event
    end

    @ts.run

    # Wait up to 5 seconds for workers to start
    event = wait_for_event 5
    assert_equal :started, event

    # The test script crashes immediately, but it should get restarted twice.
    2.times do
      event = wait_for_event 5
      assert_equal :started, event
    end
    
    # Now it should get suspended.
    event = wait_for_event 5
    assert_equal :suspended, event

    # The test script should eventually get restarted
    event = wait_for_event 10
    assert_equal :started, event

    @ts.stop

    # Wait up to 5 seconds for workers to stop
    loop do
      event = wait_for_event 5
      break if event != :stopped
    end
  end
end
