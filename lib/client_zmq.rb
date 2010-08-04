require 'rubygems'
require 'zmq'

module Client
  module Zmq
    def initialize(address, port)
      @address = address
      @port = port
      @context = ZMQ::Context.new(1)
      @socket = @context.socket(ZMQ::REQ);
      @socket.connect "tcp://#{@address}:#{@port}"
    end

    def send_message(message)
      @socket.send message, 0
    end
    
    def receive_message
      @socket.recv
    end

    def close
      @socket.close
      @context.close
    end
  end
end
