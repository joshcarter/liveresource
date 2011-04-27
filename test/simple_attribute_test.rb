require 'live_resource'
require 'test/unit'
require 'thread'

Thread.abort_on_exception = true

class FavoriteColorServer
  include LiveResource::Attribute
  
  remote_writer :color
  
  def initialize
    initialize_resource "colors.favorite"
  end
  
  def start
    ready = Queue.new

    thread = Thread.new do
      self.color = 'blue'
      ready << true
      sleep 0.1
      self.color = 'green'
    end
    
    ready.pop
    thread
  end
end

class FavoriteColorClient
  include LiveResource::Attribute

  remote_reader :color
    
  def initialize
    initialize_resource "colors.favorite"
  end
end

class SimpleResourceTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end
  
  def test_accessors_defined
    assert FavoriteColorServer.new.respond_to? :color=
    assert FavoriteColorClient.new.respond_to? :color
  end

  def test_simple_reader
    client = FavoriteColorClient.new
    server = FavoriteColorServer.new
    
    assert_equal nil, client.color
    
    thread = server.start
  
    assert_equal 'blue', client.color
    sleep 0.2
    assert_equal 'green', client.color
    
    thread.join
  end
end