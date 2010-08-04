require 'rubygems'
require 'test/unit'
require 'liveresource'

class MessageServer
  include Server::Tcp
end

class ServerConnection
  include Connection::Tcp
  include Codec::Simple

  def self.test_harness=(obj)
    @@test_harness = obj
  end

  def receive_message(message)
    @@test_harness.assert_equal "ping", message
    send_message "pong"
  end
end

class MessageClient
  include Client::Tcp
end

class ClientConnection
  include Connection::Tcp
  include Codec::Simple

  def initialize(*args)
    super(*args)
    @ponged = false
  end

  def self.test_harness=(obj)
    @@test_harness = obj
  end

  def receive_message(message)
    @@test_harness.assert_equal "pong", message
    @ponged = true
  end

  def wait_for_pong
    loop do
      return if @ponged
      Thread.pass
    end
  end
end

class SimpleMessageCodecTest < Test::Unit::TestCase
  def test_can_stop_server_with_no_connections
    server = MessageServer.new('127.0.0.1', 8081, ServerConnection)
    Thread.pass
    Thread.pass
    Thread.pass
    server.stop
  end

  def test_can_send_message_to_server
    ServerConnection.test_harness = self
    ClientConnection.test_harness = self

    server = MessageServer.new('127.0.0.1', 8081, ServerConnection)
    client = MessageClient.new('127.0.0.1', 8081, ClientConnection)

    c = client.connection
    c.send_message "ping"
    c.wait_for_pong
    c.close

    Thread.pass
    Thread.pass
    Thread.pass

    server.stop
  end
end
