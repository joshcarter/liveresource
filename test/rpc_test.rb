require 'liveresource'
require 'test/unit'

require_resource File.join(File.dirname(__FILE__), 'protos', 'rpc_test')

module Test
  class RpcService
    def operation(request)
      RpcTest::assert_block { |t| t.assert_equal 'this is the param', request.param }
      
      response = Test::Response.new
      response.result = 'this is the result'
      return response
    end
  end
end

class RpcTest < Test::Unit::TestCase
  def initialize(param)
    super param
    @@instance = self
  end

  def self.assert_block(&block)
    block.call(@@instance)
  end

  def test_send_local_operation_and_get_result
    request = Test::Request.new
    request.param = 'this is the param'

    service = Test::RpcService.new
    response = service.operation(request)
    assert_equal 'this is the result', response.result
  end
end
