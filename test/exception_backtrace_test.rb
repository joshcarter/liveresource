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
      # Specifically raise a name error as that is an excemple of one that
      # has been known to cause problems round-tripping through YAML, causing
      # an "allocator undefined for NameError::message" exception.
      raise_a_name_error
    end
  end

  def setup
    flush_redis
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

  def local_method_3(param)
    local_method_4(param)
  end
  
  def local_method_4(param)
    method = LiveResource::RemoteMethod.new(
                          :method => :resource_method_1,
                          :params => [param])
    resource = LiveResource::any(:test)
    resource.wait_for_done(resource.remote_send(method))
  end

  def test_exception_backtrace_via_most_common_access
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
  
  def test_exception_backtrace_via_shortest_stacktrace_access
    backtrace = nil
    
    begin
      local_method_3("foo")
    rescue LiveResource::Error => e
      backtrace = e.backtrace
    end
    
    # Backtrace should contain:
    # - resource_method_2
    # - resource_method_1
    # (some stuff)
    # - local_method_4
    # - local_method_3
    # (more stuff)
    rm2 = backtrace.index { |t| t =~ /resource_method_2/ }
    rm1 = backtrace.index { |t| t =~ /resource_method_1/ }
    lm2 = backtrace.index { |t| t =~ /local_method_4/ }
    lm1 = backtrace.index { |t| t =~ /local_method_3/ }
    
    assert_equal 0, rm2
    assert_equal 1, rm1
    assert lm2 > rm1
    assert_equal 1, lm1 - lm2
  end
end
