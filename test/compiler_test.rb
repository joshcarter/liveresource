require 'rubygems'
require 'test/unit'
require 'mocha'
require 'live_resource'

resource_require_stub File.join(File.dirname(__FILE__), 'protos', 'compiler_test')

module Protobuf
  module Field
    class FieldProxy
      def typename_to_class(message_class, type)
        names = type.to_s.split('::').map {|s| Util.camelize(s) }

        puts "names: #{names}"

        outer = message_class.to_s.split('::')

        puts "outer: #{outer.join(' - ')}"

        args = (Object.method(:const_defined?).arity == 1) ? [] : [false]

        puts "args: #{args.join(' - ')}"

        while
            puts "will eval: #{outer.join('::')}"
          mod = outer.empty? ? Object : eval(outer.join('::'))

          puts "mod: #{mod}"

          mod = names.inject(mod) {|m, s|
            m && m.const_defined?(s, *args) && m.const_get(s)
          }
          break if mod
          raise NameError.new("type not found: #{type}", type) if outer.empty?
          outer.pop
        end
        mod
      end
    end
  end
end

class CompilerTest < Test::Unit::TestCase
  def test_compile_generates_classes_and_modules
    assert_equal Module, Compiler.class
    assert_equal Module, Compiler::Test.class
    assert_equal Class, Compiler::Test::ResponseHeader.class
    assert_equal Class, Compiler::Test::ResponseHeader::MessageStatus.class
  end

  def test_compile_generates_enums
    assert_equal Protobuf::EnumValue, Compiler::Test::ResponseHeader::MessageStatus::QUEUED.class
    assert_equal Protobuf::EnumValue, Compiler::Test::Status::OK.class
  end

  def test_message_assignment
    fan = Compiler::Test::FanStatus.new

    require 'pp'
    pp fan.methods.sort

    fan.status = Compiler::Test::Status::OK
    fan.rotations_per_minute = 1000

    assert_equal Compiler::Test::Status::OK, fan.status
    assert_equal 1000, fan.rotations_per_minute
  end
end

