require_relative 'test_helper'

module FancyModule
  class FancyError < StandardError
  end
end

class ExceptionDeserializeTest < Test::Unit::TestCase
  class TestResource
    include LiveResource::Resource
    
    resource_class :test
    resource_name :object_id

    def resource_method_1
      resource_method_2
    end
    
    private
    
    def resource_method_2
      raise(FancyModule::FancyError)
    end
  end

  def setup
    Redis.new.flushall
    TestResource.new
  end

  def teardown
    LiveResource::stop
  end
  
  def local_method_1
    local_method_2
  end
  
  def local_method_2
    LiveResource::any(:test).resource_method_1
  end
  
  def test_namespaced_exceptions
    begin
      local_method_1
    rescue FancyModule::FancyError
      assert(true)
    rescue
      assert(false)
    end
  end
end
