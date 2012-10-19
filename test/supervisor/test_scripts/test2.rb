#! /usr/bin/env ruby

Signal.trap("INT") do
  exit
end

# Sleep for two seconds then exit
sleep 1
exit
