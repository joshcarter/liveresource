require 'test/unit'
require 'task_handler'

class TaskHandlerTest < Test::Unit::TestCase
  def DISABLED_test_simple_handler
    collector = Queue.new

    task = lambda do |str|
      collector << str.reverse
    end

    t = TaskHandler.new(task)
    t << "foobar"

    assert_equal "raboof", collector.pop

    t.stop
  end

  def DISABLED_test_pipeline
    collector = Queue.new

    downstream = TaskHandler.new do |str|
      collector << str.upcase
    end

    upstream = TaskHandler.new do |str|
      downstream << str.reverse
    end

    upstream << "foobar"

    assert_equal "RABOOF", collector.pop
    upstream.stop
    downstream.stop
  end

  def test_multithread
    counter = [0]

    def counter.increment
      @mutex ||= Mutex.new
      @mutex.synchronize { self[0] = self[0] + 1 }
    end

    def counter.count
      self[0]
    end

    assert_equal 0, counter.count

    consumers = Array.new(10) do |i|
      TaskHandler.new do |work|
        # puts "consumer #{i}: #{work}"
        counter.increment
      end
    end

    producers = Array.new(10) do |i|
      TaskHandler.new do
        100.times do |j|
          work = "producer #{i}, work unit #{j}"
          # puts work
          consumers[rand(consumers.length)] << work
        end
      end
    end

    producers.each { |p| loop { p.stopped? ? break : Thread.pass } }
    consumers.each { |c| c.stop }

    assert_equal 1000, counter.count
  end
end

