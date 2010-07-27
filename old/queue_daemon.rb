require 'rubygems'
require 'dnssd'
require 'zmq'
require 'service_info'

Thread.abort_on_exception = true

class QueueDaemon
  attr_reader :running

  def initialize(config_file)
    @service = ServiceInfo.load(config_file)

    # Per book, should always have a text record, minimally with 
    # txtvers set to 1.
    text_record = DNSSD::TextRecord.new
    text_record['txtvers'] = 1

    puts "Starting queue registration"
    DNSSD.register!(@service.name, @service.dnssd_type, 'local.', @service.port, text_record)
    puts "Registered"

    @running = true
    @thread = Thread.new do
      self.run
    end
  end

  def run
    puts "Daemon thread running"
    ctx = ZMQ::Context.new(1)
    s = ctx.socket(ZMQ::REP);
    puts "Binding to: #{@service.zmq_address}"
    s.bind(@service.zmq_address)

    while (!@stop_requested)
      msg = s.recv(0)
      puts "RX: #{msg}"
      s.send("PONG")
      puts "TX: PONG"
    end

    puts "Daemon thread stopping"
    @running = false
  end
end

if __FILE__ == $0
  daemon = QueueDaemon.new('test_queue.yml')

  while (daemon.running)
    sleep(1)
  end
end
