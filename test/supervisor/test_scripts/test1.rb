#! /usr/bin/env ruby

Signal.trap("INT") do
  exit
end

# Sleep forever
sleep
