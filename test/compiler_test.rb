require 'rubygems'
require 'test/unit'
require 'mocha'
require 'liveresource'

require_resource File.join(File.dirname(__FILE__), 'protos', 'compiler_test')

class CompilerTest < Test::Unit::TestCase
  def test_compile_generates_classes_and_modules
    assert_equal Module, Test.class
    assert_equal Class, Test::ResponseHeader.class
    assert_equal Class, Test::ResponseHeader::MessageStatus.class
  end

  def test_compile_generates_enums
    assert_equal Protobuf::EnumValue, Test::ResponseHeader::MessageStatus::QUEUED.class
    assert_equal Protobuf::EnumValue, Test::Status::OK.class
  end

  def test_message_assignment
    fan_status = Test::FanStatus.new

    fan_status.status = Test::Status::OK
    fan_status.rotations_per_minute = 1000

    assert_equal Test::Status::OK, fan_status.status
    assert_equal 1000, fan_status.rotations_per_minute

    assert_raise(TypeError) { fan_status.status = "foo" }
  end

  def test_generates_stub_class
    fan = Test::Fan.new

    assert fan.methods.include?("get_fan_status")

    assert_raise(NotImplementedError) { fan.get_fan_status }
  end
end

