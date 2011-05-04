require 'live_resource'
require 'test/unit'
require 'thread'

Thread.abort_on_exception = true

class UserLogin
  include LiveResource::Attribute
  
  remote_writer :user_logged_in
  remote_writer :user_logged_out
  
  def initialize(name)
    initialize_resource name
  end
  
  def start
    ready = Queue.new

    thread = Thread.new do
      user_logged_in = "Bob"
      user_logged_in = "Fred"
      user_logged_out = "Fred"

      sleep 0.1

      user_logged_in = "Susan"
      user_logged_out = "Bob"
      user_logged_out = "Susan"
    end
    
    ready.pop
    thread
  end
end

class AuditLog
  include LiveResource::Subscriber

  remote_subscription :user_logged_in, :login
  remote_subscription :user_logged_out, :logout
  remote_subscription :sudo # Implies method name

  def initialize(name)
    @file = StringIO.new("", "r+")
    @logger = Logger.new(@file)
    
    initialize_resource name
  end
  
  def login(user)
    @logger.info "User #{user} logged in"
  end
  
  def logout(user)
    @logger.info "User #{user} logged out"
  end
  
  def sudo(user, command)
    @logger.info "User #{user} ran #{command} as superuser"
  end
  
  def dump
    @file.rewind
    @file.readlines
  end
end

class AttributeSubscriberTest < Test::Unit::TestCase
  def test_subscriber_receives_events
    login = UserLogin.new("users")
    audit_log = AuditLog.new("users")
    
    audit_log.subscribe
    login.start

    sleep 0.25
    audit_log.unsubscribe
    
    audit_log.dump.each { |line| puts line }
  end
end
