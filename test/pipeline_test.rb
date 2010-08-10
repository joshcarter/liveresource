require 'test/unit'
require 'pipeline'

class PipelineTest < Test::Unit::TestCase
  def test_pipeline_ending_in_queue
    collector = Queue.new
    upcaser = lambda { |str| str.upcase }
    reverser = lambda { |str| str.reverse }

    # Upstream -> downstream
    p = Pipeline.new(upcaser, reverser, collector)

    assert_equal 3, p.length

    p << "foobar"
    assert_equal "RABOOF", collector.pop

    p << "barbaz"
    assert_equal "ZABRAB", collector.pop

    p.stop
  end

  def test_pipeline_ending_in_lambda
    queue = Queue.new
    collector = lambda { |str| queue.push(str); nil }
    upcaser = lambda { |str| str.upcase }
    reverser = lambda { |str| str.reverse }
    
    # Upstream -> downstream
    p = Pipeline.new(upcaser, reverser, collector)

    assert_equal 3, p.length

    p << "foobar"
    assert_equal "RABOOF", queue.pop

    p << "barbaz"
    assert_equal "ZABRAB", queue.pop

    p.stop
  end
end
