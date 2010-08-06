require 'test/unit'
require 'pipeline'

class PipelineTest < Test::Unit::TestCase
  def test_simple_pipeline
    collector = Queue.new
    upcaser = lambda { |str| str.upcase }
    reverser = lambda { |str| str.reverse }

    # Upstream -> downstream
    p = Pipeline.new(upcaser, reverser, collector)

    p << "foobar"
    assert_equal "RABOOF", collector.pop

    p << "barbaz"
    assert_equal "ZABRAB", collector.pop

    p.stop
  end
end
