require 'rpc'
require 'pp'

fan = Resource::Fan::Stub.new

loop do
  puts "Fan status:"
  pp fan.status_right_now

  break # xxx
  break if (fan.status == Response::Status::DONE)
end
