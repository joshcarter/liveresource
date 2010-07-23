require 'rubygems'
require 'test/unit'
require 'mocha'
require 'live_resource'

require_resource File.join(File.dirname(__FILE__), 'protos', 'compiler_test')

class CompilerTest < Test::Unit::TestCase
  def test_resource_has_appropriate_dnssd_type
    assert_equal '_fan._test._tcp', Test::Fan.new.dnssd_type
  end
end
