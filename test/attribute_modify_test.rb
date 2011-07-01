require File.join(File.dirname(__FILE__), 'test_helper')

class Incrementer
  include LiveResource::Attribute

  remote_accessor :value

  def initialize(initial_value)
    self.namespace = 'test'
    self.value = initial_value
  end
  
  def increment(&block)
    remote_modify(:value) do |v|
      # Allow someone else to mess with Redis while we're 
      # in the modify block.
      block.call(redis_space.clone) if block
      
      v + 1
    end
  end
end

class AttributeModifyTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
	end
	
	def test_modify_without_interference
	  i = Incrementer.new(1)
	  i.increment
	  assert_equal 2, i.value
  end

	def test_modify_with_interference
	  i = Incrementer.new(1)
	  messed_with = false

	  i.increment do |redis_space|
	    # Mess with value first time around
	    unless messed_with
	      redis_space.attribute_set('value', 10)
	      messed_with = true
      end
    end
    
    # Since the increment is replayed after LiveResource determines
    # the attribute was messed with, the final value should be one
    # increment from 10, not the original value 1.
	  assert_equal 11, i.value
  end
end
