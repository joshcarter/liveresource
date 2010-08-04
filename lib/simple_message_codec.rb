module Codec
  module Simple
    def initialize(*args)
      super(*args)

      unless respond_to?(:send_bytes)
        # Client must override this method to send encoded message.
        raise NotYetImplemented.new("Client must override Code::Simple#send_bytes")
      end

      unless respond_to?(:receive_message)
        # Client must override this method to receive decoded message.
        raise NotYetImplemented.new("Client must override Code::Simple#receive_message")
      end
    end

    # We prefix all messages with 4 bytes of size in network byte order.
    SIZE_BYTES = 4

    # Max size of a message is 2^31 bytes (2GB).
    MAX_LENGTH = (2 ** (8 * SIZE_BYTES - 1))

    # Encodes and sends message.
    def send_message(message)
      message_size = message.respond_to?(:bytesize) ? message.bytesize : message.size

      if (message_size > MAX_LENGTH)
        raise "Message is too large to send with this codec"
      end

      send_bytes [message_size, message].pack('Na*')
    end

    # Receives a raw byte stream and decodes any messages contained within.
    # If multiple messages are contained, receive_message will be called for
    # each; if only a partial message is contained, it will be buffered
    # until the rest is received in subsequent calls.
    def receive_bytes(bytes)
      @buffer ||= String.new
      @buffer << bytes

      while (@buffer.size >= SIZE_BYTES)
        message_size = @buffer.unpack('N').first

        if (@buffer.size >= SIZE_BYTES + message_size)
          @buffer.slice!(0, SIZE_BYTES)

          receive_message @buffer.slice!(0, message_size)
        else
          break
        end
      end
    end
  end
end
