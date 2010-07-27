require 'rubygems'
require 'dnssd'
require 'zmq'
require 'pp'
require 'service_info'

module Retry
  def retry_for(seconds, interval = 1, &block)
    raise ArgumentError.new("retry_for must be passed a block") if block.nil?

    start = Time.now
    while (Time.now - start < seconds)
      if block.call
        return true
      else
        sleep(interval)
      end
    end

    raise "Timed out"
  end
end

class Worker
  include Retry

  attr_reader :running

  def initialize(config_file)
    @service = ServiceInfo.load(config_file)

    @browser = DNSSD.browse(@service.dnssd_type) do |reply|
      if ((reply.flags.to_i & DNSSD::Flags::Add) != 0)
        puts "[dns-sd] Add: #{reply.name}"

        if reply.name == @service.name
          # Kick off resolution of service name

          DNSSD.resolve(@service.name, @service.dnssd_type, 'local.') do |reply|
            @service.host = reply.target
            @service.port = reply.port

            puts "[dns-sd] Found queue at #{reply.target}:#{reply.port}"
          end
        end
      else
        puts "[dns-sd] Rmv: #{reply.name}"

        if reply.name == @service.name
          # Forget any cached host name for the service
          @service.host = nil
        end
      end
    end
    puts "Browsing started"

    @running = true
    Thread.new { self.run }
  end

  def run
    puts "Worker thread running"
    ctx = ZMQ::Context.new(1)
    socket = nil
    
    begin
      loop do
        if @service.host.nil?
          socket.close unless socket.nil?
          socket = nil

          # Wait for service discovery to resolve queue
          retry_for(5, 0.25) { @service.host != nil }
        end

        if socket.nil?
          socket = ctx.socket(ZMQ::REQ); 
          socket.connect(@service.zmq_address);
        end

        puts "TX: PING"
        socket.send "PING"
        msg = socket.recv(0)
        puts "RX: #{msg}"
        sleep 1
      end
    rescue RuntimeError => e
      puts "Worker thread exception: #{e}"
    end

    @browser.stop
    puts "Browsing stopped"
    @running = false
  end
end

if __FILE__ == $0
  worker = Worker.new('test_queue.yml')

  while (worker.running)
    sleep(1)
  end
end
