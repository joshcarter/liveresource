require 'socket'

module Client
  module Tcp
    def initialize(address, port)
      @address = address
      @port = port
      @socket = TCPSocket.open(@address, @port)
    end
    
    def send_bytes(bytes)
      @socket.write(bytes)
    end

    def close
      @socket.close
    end
  end
end
