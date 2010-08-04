require 'rubygems'
require 'zmq'
require 'pp'

module Server
  module Zmq
    def initialize(address, port)
      trace "server initialize"
      @address = address
      @port = port
      @thread = Thread.new { run }
      trace "server initialized"
    end

    def trace(s)
      puts(s) if true
    end

    def run
      @context = ZMQ::Context.new(1)
      @socket = @context.socket(ZMQ::REP);
      @socket.bind "tcp://#{@address}:#{@port}"

      trace "bound to #{@address}:#{@port}"

      loop do
        begin
          trace("recv")
          receive_message @socket.recv(0)
        rescue IOError => e
          trace("exception: #{e}")

          begin
            @socket.close
            @context.close
          rescue
          end
        end

        return
      end
    end

    def stop
      trace "closing server"
      @socket.close
      trace "closing context"
      @context.close
      trace "joining thread"
      @thread.join
      trace "server stopped"
    end

    def send_message(message)
      @socket.send message
    end
  end
end
