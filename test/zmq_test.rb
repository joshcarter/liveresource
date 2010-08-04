require 'rubygems'
require 'test/unit'
require 'server_zmq'
require 'client_zmq'

class MessageServer
  include Server::Zmq

  def self.test_harness=(obj)
    @@test_harness = obj
  end

  def receive_message(message)
    puts "server: got ping"
    @@test_harness.assert_equal "ping", message
    send_message "pong"
  end
end

class MessageClient
  include Client::Zmq

  def self.test_harness=(obj)
    @@test_harness = obj
  end

  def wait_for_pong
    message = receive_message
    puts "client: got pong"
    @@test_harness.assert_equal "pong", message
  end
end

class ZmqTest < Test::Unit::TestCase
  def test_can_stop_server_with_no_connections
    server = MessageServer.new('127.0.0.1', 8081)
    Thread.pass
    Thread.pass
    Thread.pass
    server.stop
  end

  def test_can_send_message_to_server
    MessageServer.test_harness = self
    MessageClient.test_harness = self

    server = MessageServer.new('127.0.0.1', 8081)
    client = MessageClient.new('127.0.0.1', 8081)

    client.send_message "ping"
    client.close

    Thread.pass
    Thread.pass
    Thread.pass

    server.stop
  end
end
