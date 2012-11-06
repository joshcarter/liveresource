require 'rubygems'
require 'test/unit'
require 'thread'
require 'mocha'
require 'pp'

require_relative '../lib/live_resource'

Thread.abort_on_exception = true

class TestEventWaiter
  def initialize
    @q = Queue.new
  end

  def send_event(event)
    @q.push event
  end

  def wait_for_event(timeout=0)
    if timeout == 0
      event = @q.pop
    else
      timeout.times do
        begin
          break if event = @q.pop(true)
        rescue ThreadError
          sleep 1
        end
      end
    end
    event
  end
end
