require_relative 'test_helper'

class AttributesTest < Test::Unit::TestCase
  class Test
    include LiveResource::Resource

    @@class_attr = 42

    attr_reader :name, :read_only
    attr_writer :write_only
    attr_accessor :accessor

    resource_class :test
    resource_name :name

    def initialize(name)
      @name = name
      @read_only = 'foo'
      @write_only = 'bar'
      @accessor = 'baz'
    end

    def method(param1, param2)
      param1 + param2
    end

    def self.class_attr
      @@class_attr
    end

    def self.class_attr=(new_value)
      @@class_attr = new_value
    end
  end

  def setup
    Redis.new.flushall

    # Class
    LiveResource::register Test

    # Instances
    LiveResource::register Test.new("bob")
    LiveResource::register Test.new("sue")
  end

  def teardown
    LiveResource::stop
  end

  def test_true
assert true
  end

end
