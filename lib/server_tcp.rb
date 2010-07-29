require 'socket'

module Server
  module Tcp
    def initialize(address, port)
      @address = address
      @port = port
      @thread = Thread.new { run }
    end

    def run
      @server = TCPServer.open(@address, @port)
      sockets = [@server]

      begin
        loop do
          # Block waiting for socket activity
          ready = select(sockets, [], [], nil)
          readable = ready[0]

          readable.each do |socket|
            if (socket == @server)
              # New incoming connection
              client = @server.accept
              sockets << client
            else
              # Bytes ready from client
              bytes = socket.recv_nonblock(16 * 1024)

              if (bytes.empty?)
                sockets.delete(socket)
                socket.close
              else
                receive_bytes(bytes)
              end
            end
          end
        end
      rescue IOError => e
        # Stop server
        begin
          sockets.each { |s| s.close }
        rescue
        end
      end
    end

    def stop
      @server.close
      @thread.join
    end
  end
end
