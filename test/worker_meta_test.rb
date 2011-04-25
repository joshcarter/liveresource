# require 'live_resource'
require 'test/unit'
require 'thread'
require 'yaml'

class TestSuperclass
  singleton_class = class << self; self; end

  # Create event hook methods like on_start, on_stop, etc..
  singleton_class.class_eval do
    [:start, :stop].each do |event|
      define_method("on_#{event}") do |*method_names|
        @event_hooks ||= Hash.new
        @event_hooks[event] ||= []
        @event_hooks[event] += method_names
      end
    end
  end

  def main
    puts "entering main, class #{self.class}"
    event_hooks(:start)
    
    begin
      puts "running main"
    ensure
      event_hooks(:stop)
    end
  end
  
private

  def event_hooks(event)
    instance = self # Instance needed below

    self.class.instance_eval do
      methods = @event_hooks[event]
      
      return if methods.nil?
      
      methods.each { |m| instance.send(m) }
    end
  end

end

class TestSubclass < TestSuperclass
  on_start :my_start_hook
  on_stop :my_stop_hook, :my_stop_hook2

  def my_start_hook
    puts "startup method one, self: #{self}"
  end
  
  def my_stop_hook
    puts "stop method 1"
  end

  def my_stop_hook2
    puts "stop method 2"
  end
end

class WorkerMetaTest < Test::Unit::TestCase
  def test_on_start_stop
    t = TestSubclass.new
    t.main
  end
end
