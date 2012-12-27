# Test program for the LR console -- run this from a terminal window.

require_relative '../lib/live_resource'
require_relative '../lib/live_resource/console'

class Resource1
  include LiveResource::Resource
  
  resource_class :r1
  resource_name :object_id

  def test
    "Resource1.test"
  end
end

class Resource2
  include LiveResource::Resource
  
  resource_class :r2
  resource_name :object_id

  def test
    "Resource2.test"
  end
end

trap("SIGINT") do
  warn "top-level sigint"
  LiveResource::Console.start
end

Redis.new.flushall
Resource1.new
Resource2.new

begin
  loop do
    puts "Resources running."
    sleep
  end
ensure
  LiveResource::stop
end
