require 'socket'

module Connection
  module Tcp
    attr_reader :socket

    def initialize(socket, parent)
      @socket = socket
      @parent = parent
      trace "initialize #{self.object_id}, parent #{parent.inspect}"

      unless respond_to?(:receive_message)
        raise NotYetImplemented.new("Client must override Connection#receive_message")
      end
    end

    def trace(s)
      puts("  #{s}") if false
    end

    def send_bytes(bytes)
      trace "tx #{self.object_id}: #{bytes.size} bytes"
      @socket.write(bytes)
    end

    def receive_bytes(bytes)
      trace "rx #{self.object_id}: #{bytes.size} bytes"
      super(bytes)
    end

    def close
      trace "close #{self.object_id}"
      @parent.close_connection(self)
    end
  end
end
