require_relative 'test_helper'

class C
  include LiveResource::LogHelper

  def initialize
    @log_backend = StringIO.new("", "r+")
    self.logger = Logger.new(@log_backend)
  end

  def generate_debug
    debug "my debug message"
  end

  def generate_fatal
    fatal "my fatal message"
  end

  def dump
    @log_backend.rewind
    @log_backend.readlines
  end
end

class LoggerTest < Test::Unit::TestCase
  def test_basic_logging
    c = C.new
    c.generate_fatal

    assert_match "my fatal message", c.dump[0]
  end

  def test_changing_log_levels
    c = C.new
    c.logger.level = Logger::WARN

    c.generate_debug
    assert_equal 0, c.dump.length

    c.logger.level = Logger::DEBUG
    c.generate_debug
    assert_match "my debug message", c.dump[0]
  end
end
