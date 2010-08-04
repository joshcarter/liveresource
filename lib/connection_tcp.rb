require 'socket'

module Connection
  module Tcp
    attr_reader :socket

    def initialize(socket, parent)
      @socket = socket
      @parent = parent
      trace "initialize #{self.object_id}, parent #{parent.inspect}"
    end

    def trace(message)
      puts("  #{message}") if true
    end

    def send_bytes(bytes)
      trace "tx #{self.object_id}: #{bytes.size} bytes"
      @socket.write(bytes)
    end

    def receive_bytes(bytes)
      trace "rx #{self.object_id}: #{bytes.size} bytes"
      super(bytes)
    end

    def receive_message(message)
      raise NotYetImplemented.new("Client must override Connection.receive_message")
    end

    def close
      trace "close #{self.object_id}"
      @parent.close_connection(self)
    end
  end
end
