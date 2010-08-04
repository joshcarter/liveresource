require 'rubygems'
require 'test/unit'
require 'liveresource'
require 'socket'

class SocketServer
  def initialize(address, port, test_harness)
    @address = address
    @port = port
    @test_harness = test_harness
    @stop_request_read, @stop_request_write = IO.pipe

    @thread = Thread.new { run }
  end

  def run
    server = TCPServer.open(@address, @port)
    sockets = [server, @stop_request_read]

    loop do
      ready = select(sockets, [], [], nil)
      readable = ready[0]
      
      readable.each do |socket|
        if (socket == @stop_request_read)
          # Server stop request
          sockets.delete(@stop_request_read)
          @stop_request_read.read
          @stop_request_read.close

          # Close all outstanding connections
          sockets.each { |s| s.close }

          return
        elsif (socket == server)
          # New incoming connection
          client = server.accept
          sockets << client
        else
          # Came from a client
          bytes = socket.recv_nonblock(16 * 1024)

          if (bytes.empty?)
            sockets.delete(socket)
            socket.close
          else
            handle_bytes(socket, bytes)
          end
        end
      end
    end
  end

  def stop
    @stop_request_write.write "stop"
    @stop_request_write.close
    @thread.join
  end
  
  protected

  def handle_bytes(socket, bytes)
    @test_harness.assert_equal "ping", bytes
    socket.write "pong"
  end
end

class SocketClient
  def initialize(address, port)
    @address = address
    @port = port
  end

  def send_and_wait(request)
    response = nil

    TCPSocket.open(@address, @port) do |socket|
      socket.write request

      ready = IO.select([socket], [], [], nil)
      readable = ready[0]
      
      if (readable.first == socket)
        response = socket.read_nonblock(16 * 1024)
        break
      end
    end

    return response
  end

  def send_and_close(request)
    TCPSocket.open(@address, @port) do |socket|
      socket.write request
      # Don't read response, just bail
    end
  end
end

class SocketTest < Test::Unit::TestCase
  def setup
    @address = '127.0.0.1'
    @port = 8088
  end

  def test_full_path
    server = SocketServer.new(@address, @port, self)
    client = SocketClient.new(@address, @port)

    response = client.send_and_wait("ping")
    assert_equal "pong", response

    server.stop
  end

  def test_client_early_close
    server = SocketServer.new(@address, @port, self)
    client = SocketClient.new(@address, @port)

    client.send_and_close("ping")
    server.stop
  end
end
