require 'rubygems'
require 'dnssd'
require File.join(File.dirname(__FILE__), 'service_info')

Thread.abort_on_exception = true

module DnssdService
  attr_reader :service

  # Add DNS-SD server/stub methods
  def self.assimilate(object, service_name, service_port = nil)
    object.extend DnssdService
    object.instance_variable_set(:@running, false)
    object.run(service_name, service_port)
  end

  def run(service_name, service_port)
    raise "Object is already a DNS-SD service" if @running

    # Convert ancestor chain from CamelStyle to underscore_style
    type = self.class.to_s.gsub(/\B[A-Z]/, '_\&').downcase

    # Convert ancestor chain from module style to DNS-SD service type
    # i.e., foo::bar::baz becomes _baz._bar._foo
    type = type.split('::').reverse.join('_')

    # TODO: guarantee port cannot conflict
    service_port = ((service_name + type).hash % 10000) + 10000

    @service = ServiceInfo.new(
      :type => type,
      :name => service_name,
      :port => service_port)

    @running = true
    @thread = Thread.new do
      self.main
    end
  end

  def main
    # Per book, should always have a text record, minimally with 
    # txtvers set to 1.
    text_record = DNSSD::TextRecord.new
    text_record['txtvers'] = 1

    # puts "Starting queue registration"
    DNSSD.register!(@service.name, @service.dnssd_type, 'local.', @service.port, text_record)
    # puts "Registered"

    puts "Dispatcher thread running"

    sleep(2)

    puts "Dispatcher thread stopping"
    @running = false
  end
end

