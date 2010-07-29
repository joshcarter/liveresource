require 'rubygems'
require 'test/unit'
require 'live_resource'
require 'eventmachine'

require_resource File.join(File.dirname(__FILE__), 'protos', 'event_machine_test')

class NullSerializer
  def self.dump(bytes)
    bytes
  end

  def self.load(bytes)
    bytes
  end
end

module EventMachine
  module Protocols
    module ObjectProtocol
      def serializer
        NullSerializer
      end
    end
  end
end

class EventMachineResponder < EventMachine::Connection
  include EventMachine::Protocols::ObjectProtocol

  def self.new(*args)
    super(args)

    EventMachine::start_server "127.0.0.1", 8081, self
  end

  def receive_object(bytes)
    message = Test::EventMessage.new
    message.parse_from_string(bytes)

    puts "Server received:"
    puts "  - foo: #{message.foo}"
    puts "  - bar: #{message.bar}"
    puts "  - baz: #{message.baz}"
    
    message = Test::EventMessage.new
    message.foo = "Reply foo from server"
    
    send_object(message.serialize_to_string)
  end
end

class ResponseReceived < RuntimeError
end

class EventMachineInquirer < EventMachine::Connection
  include EventMachine::Protocols::ObjectProtocol

  def self.new(*args)
    super(args)

    EventMachine::connect "127.0.0.1", 8081, self
  end

  def inquire
    message = Test::EventMessage.new
    message.bar = "Bar from inquirer"

    begin
      @thread = Thread.current
      send_object(message.serialize_to_string)
      @thread.stop
    rescue ResponseReceived
      # Fall through and return
    end
  end

  def receive_object(bytes)
    message = Test::EventMessage.new
    message.parse_from_string(bytes)

    puts "Inquirer received:"
    puts "  - foo: #{message.foo}"
    puts "  - bar: #{message.bar}"
    puts "  - baz: #{message.baz}"

    @thread.raise(ResponseReceived.new)
  end
end


class EventMachineTest < Test::Unit::TestCase
  def test_event_machine
    EventMachine.run do
      responder = EventMachineResponder.new
      inquirer = EventMachineInquirer.new
      Thread.new { inquirer.inquire }
      EventMachine::add_timer(1) { EventMachine::stop }
    end
  end
end
