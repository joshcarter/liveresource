require 'rubygems'
require 'test/unit'
require 'mocha'
require 'live_resource'
require 'pp'

require_resource File.join(File.dirname(__FILE__), 'protos', 'service_test')

class ServiceTest < Test::Unit::TestCase
  def test_can_assimilate_one_object
    Thread.expects(:new).once.returns(nil) # don't actually create thread

    s1 = Service.new(Test::TestService, 'My service')
    s2 = Test::TestService.new

    assert_equal true, s1.respond_to?(:run)
    assert_equal false, s2.respond_to?(:run)
  end

  def test_resource_has_appropriate_dnssd_type
    Thread.expects(:new).once.returns(nil) # don't actually create thread

    s = Service.new(Test::TestService, 'My service')

    assert_equal '_test_service_test._tcp', s.info.dnssd_type
  end

  def disable_test_dnssd_can_stop_main_thread
    DNSSD.expects(:register!).once.returns(nil)

    s = Service.new(Test::TestService.new, 'My service')
    s.stop
  end
end
