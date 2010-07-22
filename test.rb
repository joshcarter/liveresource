require 'resource'
require 'pp'

fan = Resource::Fan::Stub.new

loop do
  puts "Fan status:"
  pp fan.status

  break # xxx
  break if (fan.status == Response::Status::DONE)
end
