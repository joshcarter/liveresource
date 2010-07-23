require 'rubygems'
require 'test/unit'
require 'mocha'
require 'live_resource'

require_resource File.join(File.dirname(__FILE__), 'protos', 'compiler_test')

class CompilerTest < Test::Unit::TestCase
  def test_resource_has_appropriate_dnssd_type
    fan = Test::Fan.new
    assert_equal '_fan_test._tcp', fan.instance_variable_get(:@service).dnssd_type
  end

  def test_resource_can_become_server
    fan = Test::Fan.new

    fan.expects(:run).once
    fan.run("foo")
  end
end
