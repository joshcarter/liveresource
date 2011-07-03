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

class Client
  include LiveResource::MethodSender
  
  def fancy_process(a, b)
    begin
      puts remote_send :divide, a, b
    rescue ArgumentError => e
      puts "oops, I messed up: #{e}"
    end
  end
end

s = Server.new
s.namespace = "math"
s.start_method_dispatcher

c = Client.new
c.namespace = "math"
c.fancy_process(10, 5)
c.fancy_process(1, 0)

s.stop_method_dispatcher
