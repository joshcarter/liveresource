require 'rubygems'
require 'test/unit'
require 'mocha'
require 'live_resource'
require 'pp'

require_resource File.join(File.dirname(__FILE__), 'protos', 'dnssd_test')

class CompilerTest < Test::Unit::TestCase
  def test_can_assimilate_one_object
    Thread.expects(:new).once.returns(nil) # don't actually create thread

    s1 = Test::DnssdTestService.new
    s2 = Test::DnssdTestService.new

    DnssdService.assimilate(s1, 'My service')

    assert_equal true, s1.respond_to?(:run)
    assert_equal false, s2.respond_to?(:run)
  end

  def test_resource_has_appropriate_dnssd_type
    Thread.expects(:new).once.returns(nil) # don't actually create thread

    s = Test::DnssdTestService.new
    DnssdService.assimilate(s, 'My service')

    assert_equal '_dnssd_test_service_test._tcp', s.service.dnssd_type
  end

  def disable_test_dnssd_can_stop_main_thread
    DNSSD.expects(:register!).once.returns(nil)

    s = Test::DnssdTestService.new
    DnssdService.assimilate(s, 'My service')
    s.stop
  end
end
