require 'rubygems'
require 'lib/live_resource'

class Server
  include LiveResource::MethodProvider

  remote_method :divide

  def divide(dividend, divisor)
    raise ArgumentError.new("cannot divide by zero") if divisor == 0
    
    dividend / divisor
  end
end

s = Server.new
s.namespace = "math"
s.logger.level = Logger::INFO

Signal.trap("INT") { s.stop_method_dispatcher }

s.start_method_dispatcher.join
