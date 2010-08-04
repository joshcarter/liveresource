require 'socket'
require 'pp'

module Server
  module Tcp
    def initialize(address, port, connection_class)
      @address = address
      @port = port
      @connection_class = connection_class
      @thread = Thread.new { run }
    end

    def trace(s)
      puts(s) if false
    end

    def run
      @server = TCPServer.open(@address, @port)
      @connections = []

      loop do
        begin
          sockets = [@server] + @connections.map { |c| c.socket }

          # Block waiting for socket activity
          ready = select(sockets, [], [], nil)
          readable = ready[0]

          readable.each do |socket|
            if (socket == @server)
              # New incoming connection
              client = @server.accept
              @connections << @connection_class.new(client, self)
              trace "accepting new connection from #{client.peeraddr[2]}"
            else
              # Find connection matching this socket
              connection = @connections.find { |c| c.socket == socket }

              begin
                bytes = socket.recv_nonblock(16 * 1024)

                if (bytes.empty?)
                  trace "connection closed from #{socket.peeraddr[2]}"
                  connection.close
                else
                  connection.receive_bytes(bytes)
                end
              rescue Errno::ECONNRESET
                trace "connection reset"
                @connections.delete(connection)
              end
            end
          end
        rescue IOError => e
          # Close all sockets
          sockets = [@server] + @connections.map { |c| c.socket }

          sockets.each do |s|
            begin
              s.close
            rescue
            end
          end

          return
        end
      end
    end

    def stop
      @server.close
      @thread.join
    end

    def close_connection(connection)
      @connections.delete(connection)
      connection.socket.close
    end
  end
end
