require File.join(File.dirname(__FILE__), 'test_helper')

class FavoriteColorServer
  include LiveResource::Attribute
  
  remote_writer :color
  remote_accessor :foo, :bar
  
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

    @client = FavoriteColorClient.new
    @server = FavoriteColorServer.new
  end
  
  def test_accessors_defined
    assert @client.respond_to? :color
    assert @server.respond_to? :color=
  end

  def test_simple_read_write
    assert_equal nil, @client.color
    
    thread = @server.start
  
    assert_equal 'blue', @client.color
    sleep 0.2
    assert_equal 'green', @client.color
    
    thread.join
  end
  
  def test_accessor
    assert @server.respond_to? :foo
    assert @server.respond_to? :foo=
    assert @server.respond_to? :bar
    assert @server.respond_to? :bar=

    @server.foo = 'foo'
    assert_equal 'foo', @server.foo
    
    @server.bar = @server.foo
    assert_equal 'foo', @server.bar
  end
end