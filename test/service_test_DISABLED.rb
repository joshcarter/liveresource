require 'rubygems'
require 'test/unit'
require 'mocha'
require 'liveresource'
require 'pp'

require_resource File.join(File.dirname(__FILE__), 'protos', 'service_test')

module Test
  class TestService

    def test_method(parameter)
      p = Test::TestServiceParameter.new
      p.parse_from_string(parameter)

      puts "Got RPC:"
      puts "  - foo: #{p.foo}"
      puts "  - bar: #{p.bar}"
      puts "  - baz: #{p.baz}"

      r = Test::TestServiceResult.new
      r.code = Test::TestServiceResult::Code::OK
      return r
    end
  end
end

class ServiceTest < Test::Unit::TestCase
  def DISABLED_test_can_assimilate_one_object
    Thread.expects(:new).once.returns(nil) # don't actually create thread

    s1 = Service.new(Test::TestService, 'My service')
    s2 = Test::TestService.new

    assert_equal true, s1.respond_to?(:run)
    assert_equal false, s2.respond_to?(:run)
  end

  def DISABLED_test_resource_has_appropriate_dnssd_type
    Thread.expects(:new).once.returns(nil) # don't actually create thread

    s = Service.new(Test::TestService, 'My service')

    assert_equal '_test_service_test._tcp', s.info.dnssd_type
  end

  def test_can_stop_service_thread
    DNSSD.expects(:register!).once.returns(nil)

    puts "creating service"
    s = Service.new(Test::TestService, 'My service')
    puts "service created"

    sleep 3
    puts "I'm about to call stop"
    s.stop
  end

  def DISABLED_test_can_send_rpc_to_service_thread
    s = Service.new(Test::TestService, 'My service')

    param = Test::TestServiceParameter.new
    param.foo = 'this is foo'

    msg = Rpcmsg::Header.new
    msg.method = 'test_method'
    msg.parameter = param.serialize_to_string

    ctx = ZMQ::Context.new(1)
    @rpc_sender = ctx.socket(ZMQ::REQ);
    @rpc_sender.connect(s.info.zmq_address)
    @rpc_sender.send(msg.serialize_to_string)

    sleep 1

    s.stop
  end
end
