require 'rubygems'
require 'dnssd'
require 'zmq'
require File.join(File.dirname(__FILE__), 'service_info')

module Client
  attr_reader :info

  # Create new client based on klass.
  def self.new(klass, service_name, service_port = nil)
    object = klass.new
    object.extend Client
    return object
  end

  
end
