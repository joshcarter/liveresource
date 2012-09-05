require_relative 'test_helper'

class ParamsTest < Test::Unit::TestCase
  class ParamsClass
    include LiveResource::Resource

    remote_reader :name
    remote_reader :age

    resource_name :name
    resource_class :params_class

    def initialize(name, age)
      remote_attribute_write(:name, name)
      remote_attribute_write(:age, age)
    end

    def no_params_method
      self.age
    end

    def fixed_params_method(arg1, arg2)
      arg1 + arg2
    end

    def splat_params_method(*params)
      params.length
    end

    def mixed_params_method(arg1, arg2, *params)
      result = arg1 + arg2
      params.each do |param|
        result = result + param
      end
      result
    end
  end

  def setup
    Redis.new.flushall

    LiveResource::RedisClient.logger.level = Logger::INFO

    # Class resources
    LiveResource::register ParamsClass

    @test_class = LiveResource::find(:params_class)
    @test_instance = @test_class.new("bob", 42)
  end

  def teardown
    LiveResource::stop
  end

  def test_no_params_method
    assert_equal 42, @test_instance.no_params_method
    assert_raise(ArgumentError) { @test_instance.no_params_method("foo") }
  end

  def test_fixed_params_method
    assert_equal 13, @test_instance.fixed_params_method(6, 7)
    assert_raise(ArgumentError) { @test_instance.fixed_params_method }
    assert_raise(ArgumentError) { @test_instance.fixed_params_method(6, 7, 8) }
  end

  def test_splat_params_method
    assert_equal 0, @test_instance.splat_params_method
    assert_equal 1, @test_instance.splat_params_method("foo")
    assert_equal 2, @test_instance.splat_params_method("foo", "bar")
    assert_equal 3, @test_instance.splat_params_method("foo", "bar", "baz")
  end

  def test_mixed_params_method
    assert_equal 3, @test_instance.mixed_params_method(1, 2)
    assert_equal 6, @test_instance.mixed_params_method(1, 2, 3)
    assert_equal 10, @test_instance.mixed_params_method(1, 2, 3, 4)

    assert_raise(ArgumentError) { @test_instance.mixed_params_method }
    assert_raise(ArgumentError) { @test_instance.mixed_params_method(1) }
  end
end
