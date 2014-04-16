#! /usr/bin/env ruby
require_relative '../../test_helper'

class TestMaterialize
  include LiveResource::Resource

  resource_class :test_materialize
  resource_name :name

  remote_accessor :name
  remote_accessor :value

  def initialize(name, value)
    # Only overwrite our name if it doesn't exist yet
    remote_attribute_writenx(:name, name)

    # Always overwrite our value
    self.value = value
  end
end

ts = LiveResource::Supervisor::Supervisor.new
ew = TestEventWaiter.new

Signal.trap("TERM") do
  Thread.new do
    ts.stop
    raise RuntimeError unless ew.wait_for_event(5) == :stopped
    exit
  end
end

ts.supervise_resource TestMaterialize do |on|
  on.stopped { |worker| ew.send_event :stopped }
end
ts.run
sleep
