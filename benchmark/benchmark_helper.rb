require 'rubygems'
require 'test/unit'
require 'thread'
require 'pp'
require 'benchmark'

require_relative '../lib/live_resource'

Thread.abort_on_exception = true

class String
  def pad(pad_to = 70)
    self.ljust(pad_to)
  end

  def title
    "*\n* #{self}\n*\n"
  end
end
