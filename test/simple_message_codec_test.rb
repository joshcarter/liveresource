require 'rubygems'
require 'test/unit'
require 'liveresource'

# Class that just buffers sent messages
class NullSender
  include Codec::Simple
  attr_reader :buffer

  def initialize
    @buffer = String.new
  end

  def send_bytes(bytes)
    @buffer << bytes
  end
end

# Class that just buffers received messages
class NullReceiver
  include Codec::Simple
  attr_reader :messages

  def initialize
    @messages = []
  end

  def receive_message(message)
    @messages << message
  end
end

class SimpleMessageCodecTest < Test::Unit::TestCase
  def test_message_size_boundaries
    assert_equal 2147483648, Codec::Simple::MAX_LENGTH
  end

  def test_send_receive_one_message
    sender = NullSender.new
    receiver = NullReceiver.new

    sender.send_message("foo")

    # Ensure length byte is correct
    assert_equal [3].pack("N"), sender.buffer.slice(0, 4)

    # Now receive the message
    receiver.receive_bytes(sender.buffer)

    assert_equal 1, receiver.messages.length
    assert_equal "foo", receiver.messages.first
  end

  def test_receive_message_in_chunks
    sender = NullSender.new
    receiver = NullReceiver.new

    sender.send_message("foobarbaz")

    # Split the message into chunks
    buffer = sender.buffer
    assert_equal 13, buffer.size
    buffers = [buffer[0...2], buffer[2...3], buffer[3...6], buffer[6, 13]]

    # Receive each chunk
    buffers.each { |b| receiver.receive_bytes(b) }

    assert_equal "foobarbaz", receiver.messages.first
  end

  def test_receive_multiple_messages
    sender = NullSender.new
    receiver = NullReceiver.new

    sender.send_message("foo")
    sender.send_message("bar")
    sender.send_message("baz")

    receiver.receive_bytes(sender.buffer)

    assert_equal 3, receiver.messages.length
    assert_equal "foo", receiver.messages[0]
    assert_equal "bar", receiver.messages[1]
    assert_equal "baz", receiver.messages[2]
  end

  def test_receive_multiple_and_partial_messages
    sender = NullSender.new
    receiver = NullReceiver.new

    sender.send_message("foo")
    sender.send_message("bar")
    sender.send_message("baz")
    
    # Split buffer into two chunks, so part of last message is separate
    buffer = sender.buffer
    buffers = [buffer[0...-3], buffer[-3..-1]]

    # Receive first chunk
    receiver.receive_bytes buffers[0]

    assert_equal 2, receiver.messages.length
    assert_equal "foo", receiver.messages[0]
    assert_equal "bar", receiver.messages[1]

    # Receive last chunk
    receiver.receive_bytes buffers[1]

    assert_equal 3, receiver.messages.length
    assert_equal "baz", receiver.messages[2]
  end
end
