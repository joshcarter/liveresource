require 'rubygems'
require 'test/unit'
require 'thread'
require 'pp'
require 'live_resource'
require 'benchmark'

Thread.abort_on_exception = true

class String
  def pad(pad_to = 50)
    self.ljust(pad_to)
  end

  def title
    "*\n* #{self}\n*\n"
  end
end
