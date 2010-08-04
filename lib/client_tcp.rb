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
    end
    
    def close_connection(connection)
      raise "Invalid parent for connection #{connection}" unless (connection == @connection)

      @connection.socket.close
      @connection = nil
    end
  end
end
