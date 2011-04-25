require 'test/unit'
require 'thread'
require 'live_resource/worker'
require 'pp'

# Simplified version of what LiveResource::Worker does with on_start, 
# on_stop, and remote_method hooks. This version takes a pre-canned
# list of "remote" methods to execute and captures the results of all
# hooks.
class MockWorker < LiveResource::Worker
  attr_reader :results
  
  def initialize(method_queue = Queue.new)
    @results = Hash.new
    main(method_queue)
  end

  def main(method_queue)
    event_hooks(:on_start)
    
    while !method_queue.empty?
      method_name = method_queue.pop

      method = self.class.instance_eval do
        @event_hooks[:remote_method].find { |m| m == method_name }
      end
      
      results[:remote_method] ||= []
      results[:remote_method] << send(method)
    end
    
    event_hooks(:on_stop)
  end
  
  private
  
  def event_hooks(event)
    instance = self # Instance needed below

    self.class.instance_eval do
      methods = @event_hooks[event]
      
      return if methods.nil?
      
      methods.each do |m|
        instance.results[event] ||= []
        instance.results[event] << instance.send(m)
      end
    end
  end
end

# Simplest case: one hook.
class TestWorker1 < MockWorker
  on_start :my_start_method1
  
  def my_start_method1
    1
  end
end

# Slightly harder case: multiple methods to call for a single event.
class TestWorker2 < MockWorker
  on_start :my_start_method1, :my_start_method2
  on_start :my_start_method3
  
  def my_start_method1
    1
  end

  def my_start_method2
    2
  end

  def my_start_method3
    3
  end
end

# Full case: all hooks utilized.
class TestWorker3 < MockWorker
  on_start :start
  on_stop :stop
  
  remote_method :method1, :method2
  remote_method :method3
  
  def start
    "start result"
  end

  def stop
    "stop result"
  end

  def method1
    "result 1"
  end

  def method2
    "result 2"
  end

  def method3
    "result 3"
  end
end

class WorkerDefinitionTest < Test::Unit::TestCase
  def test_register_one_start_hooks
    w = TestWorker1.new
    assert_equal [1], w.results[:on_start]
  end

  def test_register_multi_start_hooks
    w = TestWorker2.new
    assert_equal [1, 2, 3], w.results[:on_start]
  end
  
  def test_method_hooks
    q = Queue.new
    q << :method2
    q << :method1
    q << :method3
    
    w = TestWorker3.new(q)
    
    assert_equal ["start result"], w.results[:on_start]
    assert_equal ["stop result"], w.results[:on_stop]
    assert_equal ["result 2", "result 1", "result 3"], w.results[:remote_method]
  end

  def test_no_method_hook_defined
    # This test matches the logic in worker.rb's method lookup
    method = :method1

    method = TestWorker3.class_eval do
      @event_hooks[:remote_method] &&
      @event_hooks[:remote_method].find { |m| m == method }
    end
    
    assert_equal Symbol, method.class
    assert_equal 0, TestWorker3.new.method(method).arity

    # Now for an undefined method
    method = :no_such_method

    method = TestWorker3.class_eval do
      @event_hooks[:remote_method] &&
      @event_hooks[:remote_method].find { |m| m == method }
    end
    
    assert_equal nil, method
  end
end
