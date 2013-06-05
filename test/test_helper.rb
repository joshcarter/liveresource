if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
  end
end

require 'rubygems'
require 'test/unit'
require 'thread'
require 'pp'

require_relative '../lib/live_resource'

Thread.abort_on_exception = true

ENV['LIVERESOURCE_DB'] ||= '15'

class Test::Unit::TestCase
  def flush_redis
    LiveResource::RedisClient.redis.flushdb
  end

  def redis_dbsize
    LiveResource::RedisClient.redis.dbsize
  end
end

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

  def empty?
    @q.empty?
  end
end
