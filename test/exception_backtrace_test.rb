require_relative 'test_helper'

class ExceptionBacktraceTest < Test::Unit::TestCase
  class TestResource
    include LiveResource::Resource
    
    resource_class :test
    resource_name :object_id

    def resource_method_1(param)
      resource_method_2(param)
    end
    
    private
    
    def resource_method_2(param)
      raise "failure"
    end
  end

  def setup
    Redis.new.flushall
    TestResource.new
  end

  def teardown
    LiveResource::stop
  end
  
  def local_method_1(param)
    local_method_2(param)
  end
  
  def local_method_2(param)
    LiveResource::any(:test).resource_method_1(param)
  end
  
  def test_exception_backtrace
    backtrace = nil
    
    begin
      local_method_1("foo")
    rescue LiveResource::Error => e
      backtrace = e.backtrace
    end
    
    # Backtrace should contain:
    # - resource_method_2
    # - resource_method_1
    # (some stuff)
    # - local_method_2
    # - local_method_1
    # (more stuff)
    rm2 = backtrace.index { |t| t =~ /resource_method_2/ }
    rm1 = backtrace.index { |t| t =~ /resource_method_1/ }
    lm2 = backtrace.index { |t| t =~ /local_method_2/ }
    lm1 = backtrace.index { |t| t =~ /local_method_1/ }
    
    assert_equal 0, rm2
    assert_equal 1, rm1
    assert lm2 > rm1
    assert_equal 1, lm1 - lm2
  end
end
