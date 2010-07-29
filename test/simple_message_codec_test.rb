require 'rubygems'
require 'test/unit'
require 'simple_message_codec'

class NullSender
  include Codec::Simple
  attr_reader :buffer

  def initialize
    @buffer = nil
  end

  def send_bytes(bytes)
    @buffer = bytes
  end
end

class NullReceiver
  include Codec::Simple
  attr_reader :message

  def initialize
    @message = nil
  end

  def receive_message(message)
    @message = message
  end
end

class SimpleMessageCodecTest < Test::Unit::TestCase
  def test_message_size_boundaries
    assert_equal 2147483648, Codec::Simple::MAX_LENGTH
  end

  def test_send_receive
    sender = NullSender.new
    sender.send_message("foo")

    # Ensure length byte is correct
    assert_equal [3].pack("N"), sender.buffer.slice(0, 4)

    # Now receive the message
    receiver = NullReceiver.new
    receiver.receive_bytes(sender.buffer)

    assert_equal "foo", receiver.message
  end
end
