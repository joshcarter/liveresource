require 'test/unit'
require 'service_browser'

Thread::abort_on_exception = true

class ServiceProvider
  NAME = 'Test Provider'
  TYPE = 'test_provider'
  PROTOCOL = 'tcp'
  DOMAIN = 'local.'

  def initialize
    @incoming = Queue.new
    @outgoing = Queue.new
    @thread = Thread.new { run }
  end
  
  def run
    DNSSD.register!(NAME, "_#{TYPE}._#{PROTOCOL}", DOMAIN, 10081, nil)

    loop do
      r = @incoming.pop
      return if r == :stop
      @outgoing.push r
    end
  end

  def stop
    @incoming.push :stop
  end

  def wait_for_register
    @incoming.push :just_checking
    @outgoing.pop
  end
end

class ServiceBrowserTest < Test::Unit::TestCase
  def setup
    @browser = ServiceBrowser.new(ServiceProvider::TYPE, ServiceProvider::PROTOCOL)
  end

  def teardown
    @browser.stop
  end

  def test_resolution_fails_with_no_service
    sleep 0.1
    assert_nil @browser[ServiceProvider::NAME]
  end

  def test_resolution_finds_service
    provider = ServiceProvider.new
    provider.wait_for_register

    sleep 1
    assert_equal ServiceProvider::NAME, @browser[ServiceProvider::NAME].name
    provider.stop
  end
end
