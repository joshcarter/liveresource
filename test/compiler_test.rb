require 'test/unit'
require 'resource_compiler'

require_resource File.join(File.dirname(__FILE__), 'protos', 'compiler_test')

class ProtobufCompilerTest < Test::Unit::TestCase
  def test_compile_generates_classes_and_modules
    assert_equal Module, CompilerTest.class
    assert_equal Class, CompilerTest::ResponseHeader.class
    assert_equal Class, CompilerTest::ResponseHeader::MessageStatus.class
  end

  def test_compile_generates_enums
    assert_equal Protobuf::EnumValue, CompilerTest::ResponseHeader::MessageStatus::QUEUED.class
    assert_equal Protobuf::EnumValue, CompilerTest::Status::OK.class
  end

  def test_message_assignment
    fan_status = CompilerTest::FanStatus.new

    fan_status.status = CompilerTest::Status::OK
    fan_status.rotations_per_minute = 1000

    assert_equal CompilerTest::Status::OK, fan_status.status
    assert_equal 1000, fan_status.rotations_per_minute

    assert_raise(TypeError) { fan_status.status = "foo" }
  end

  def test_generates_stub_class
    fan = CompilerTest::Fan.new

    assert fan.methods.include?("get_fan_status")

    assert_raise(NotImplementedError) { fan.get_fan_status }
  end

  def test_fails_to_require_nonpresent_file
    assert_raise(ArgumentError) { require_resource 'file_that_does_not_exist' }
  end
end

