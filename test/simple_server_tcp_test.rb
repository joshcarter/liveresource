require 'rubygems'
require 'test/unit'
require 'simple_server_tcp'
require 'simple_client_tcp'
require 'simple_message_codec'

class TcpMessageServer
  include Codec::Simple
  include Server::Tcp

  attr_writer :test_harness

  def receive_message(message)
    @test_harness.assert_equal "foo", message
  end
end

class TcpMessageClient
  include Codec::Simple
  include Client::Tcp

  # Has send_message method from Codec::Simple
end

class SimpleMessageCodecTest < Test::Unit::TestCase
  def test_can_stop_server
    server = TcpMessageServer.new('127.0.0.1', 8081)
    Thread.pass
    Thread.pass
    Thread.pass
    server.stop
  end

  def test_can_send_message_to_server
    server = TcpMessageServer.new('127.0.0.1', 8082)
    client = TcpMessageClient.new('127.0.0.1', 8082)

    server.test_harness = self

    client.send_message "foo"
    Thread.pass
    Thread.pass
    Thread.pass

    client.close
    server.stop
  end
end
