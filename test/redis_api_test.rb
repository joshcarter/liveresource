require 'rubygems'
require 'redis'
require 'test/unit'
require 'thread'

class RedisApiTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
    @@trace = false
  end

  def trace(s)
    puts("- #{s}") if @@trace
  end
  
  def publisher(channel, quantity)
    Thread.new do
      trace "Publisher started"
      redis = Redis.new
      
      quantity.times do |i|
        trace "Publishing..."
        redis.publish(channel, "news #{i + 1}")
      end
      
      trace "Publisher done"
    end
  end
    
  def subscriber(channel, quantity, messages)
    thread = Thread.new do
      redis = Redis.new

      redis.subscribe(channel) do |on|
        on.subscribe do |channel, subscriptions|
          trace "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end
        
        on.message do |channel, message|
          trace "##{channel}: #{message}"
          messages << message
          
          redis.unsubscribe if (messages.length == quantity)
        end
        
        on.unsubscribe do |channel, subscriptions|
          trace "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
        end

        trace "Subscriber started"
        thread.listening!
      end

      trace "Subscriber done"
    end
    
    def thread.listening?
      @listening
    end

    def thread.listening!
      @listening = true
    end
    
    thread
  end
  
  def test_publish_subscribe
    messages = Queue.new

    subscriber = subscriber('test', 1, messages)
    # Let subscriber get started
    Thread.pass while !subscriber.listening?

    publisher = publisher('test', 1)

    publisher.join
    subscriber.join

    assert_equal 'news 1', messages.pop
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