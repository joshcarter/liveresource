require 'socket'
require 'connection_tcp'

module Client
  module Tcp
    def initialize(address, port, connection_class)
      @address = address
      @port = port
      @connection_class = connection_class
      @connection = nil
    end

    def connection
      return @connection if @connection

      socket = TCPSocket.open(@address, @port)
      @connection = @connection_class.new(socket, self)
      @thread = Thread.new { run }
      return @connection
    end
    
    def close_connection(connection)
      raise "Invalid parent for connection #{connection}" unless (connection == @connection)

      @connection.socket.close
      @connection = nil
    end

    def run
      loop do
        begin
          # Receive any incoming bytes
          ready = select([@connection.socket], [], [], nil)
          readable = ready[0]

          readable.each do |socket|
            bytes = socket.recv_nonblock(16 * 1024)

            if (bytes.empty?)
              trace "client connection closed"
              raise IOError.new("client connection closed")
            else
              @connection.receive_bytes(bytes)
            end
          end
        rescue IOError => e
          begin
            connection.close
          rescue
          end

          return
        end
      end
    end
  end
end
