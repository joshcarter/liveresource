require 'rubygems'
require 'test/unit'
require 'mocha'
require 'live_resource'
require 'pp'

require_resource File.join(File.dirname(__FILE__), 'protos', 'dnssd_test')

class CompilerTest < Test::Unit::TestCase
  def test_can_assimilate_one_object
    Thread.expects(:new).once.returns(nil) # don't actually create thread

    fan1 = Test::Fan.new
    fan2 = Test::Fan.new

    DnssdService.assimilate(fan1, 'My fan')

    assert_equal true, fan1.respond_to?(:run)
    assert_equal false, fan2.respond_to?(:run)
  end

  def test_resource_has_appropriate_dnssd_type
    Thread.expects(:new).once.returns(nil) # don't actually create thread

    fan = Test::Fan.new
    DnssdService.assimilate(fan, 'My fan')

    assert_equal '_fan_test._tcp', fan.service.dnssd_type
  end
end
