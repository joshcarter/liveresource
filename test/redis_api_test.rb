require 'rubygems'
require 'redis'
require 'test/unit'
require 'thread'

class RedisApiTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end

  def trace(s)
    puts("- #{s}") if false
  end
  
  def DISABLED_test_publish_subscribe
    redis = Redis.new("localhost")
    done = Queue.new
    received = nil

    trace "Starting subscriber"
    Thread.new do
      trace "Registering subscriber"

      redis.subscribe('news') do |on|
        on.subscribe do |channel, subscriptions|
          trace "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end

        on.message do |channel, message|
          trace "##{channel}: #{message}"
          if message == "exit"
            redis.unsubscribe
          else
            received = message
          end
        end

        on.unsubscribe do |channel, subscriptions|
          trace "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
          done << true
        end
      end
    end
    
    trace "Starting publisher"
    Thread.new do
      sleep 1
      trace "Publishing first message"
      redis.publish 'news', 'foo'

      sleep 1
      trace "Publishing exit message"
      redis.publish 'news', 'exit'
    end
    
    trace "Waiting for done"
    done.pop
    trace "Done"
    assert_equal 'foo', received
  end
  
  def consume(list, quantity, values)
    Thread.new do
      trace "Consumer started"
      redis = Redis.new

      quantity.times do
        trace "Consuming..."
        list, value = redis.blpop list, 10
        trace "Consumed: #{value}"
        values << value
      end

      trace "Consumer done"
    end
  end
  
  def produce(list, quantity, delay = 0.0)
    Thread.new do
      trace "Producer started"
      redis = Redis.new
      
      quantity.times do
        sleep(delay) unless (delay == 0.0)
        
        trace "Producing..."
        redis.rpush list, "hello"
        trace "Produced"
      end

      trace "Producer done"
    end
  end
  
  def test_blocking_pop_consumer_starts_first
    values = Queue.new

    consumer = consume('test', 1, values)
    sleep 0.1
    producer = produce('test', 1)
    
    consumer.join
    producer.join
    
    assert_equal "hello", values.pop
  end

  def test_blocking_pop_producer_starts_first
    values = Queue.new

    producer = produce('test', 1)
    sleep 0.1
    consumer = consume('test', 1, values)
    
    consumer.join
    producer.join
    
    assert_equal "hello", values.pop
  end

  def test_blocking_pop_producer_starts_first
    values = Queue.new

    producer = produce('test', 1)
    sleep 0.1
    consumer = consume('test', 1, values)
    
    consumer.join
    producer.join
    
    assert_equal "hello", values.pop
  end
  
  def test_blocking_pop_stress
    values = Queue.new

    producer = produce('test', 1000)
    consumer = consume('test', 1000, values)
    
    consumer.join
    producer.join
    
    assert_equal "hello", values.pop
  end  
end