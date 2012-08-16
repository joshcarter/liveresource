require File.join(File.dirname(__FILE__), 'test_helper')

class TransientColorServer
  include LiveResource::Attribute
  
  # Currently the only option is TTL
  remote_writer :color, :ttl => 1
  remote_accessor :color2, :ttl => 1
  
  def initialize
    self.namespace = "colors.favorite.transient"
  end  
end

class TransientColorClient
  include LiveResource::Attribute

  remote_reader :color, :color2
    
  def initialize
    self.namespace = "colors.favorite.transient"
  end
end

class AttributeOptionsTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall

    @client = TransientColorClient.new
    @server = TransientColorServer.new
  end
  
  def test_accessors_defined
    assert @server.respond_to? :color=
    assert_equal false, @server.respond_to?(:color)
    assert @server.respond_to? :color2
    assert @server.respond_to? :color2=

    assert @client.respond_to? :color
    assert_equal false, @client.respond_to?(:color=)
    assert @client.respond_to? :color2
    assert_equal false, @client.respond_to?(:color2=)
  end

  def test_simple_read_write
    assert_equal nil, @client.color
    
    @server.color = 'blue'
    assert_equal 'blue', @client.color

    sleep 2
    assert_equal nil, @client.color
  end
end