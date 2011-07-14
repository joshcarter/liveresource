require File.join(File.dirname(__FILE__), 'test_helper')

class UserLogin
  include LiveResource::Attribute
  
  remote_writer :user_logged_in
  remote_writer :user_logged_out
  remote_writer :sudo
  
  def initialize(name)
    self.namespace = name
  end
  
  def start
    Thread.new do
      self.user_logged_in = "Bob"
      self.user_logged_in = "Fred"
      self.user_logged_out = "Fred"

      sleep 0.1

      self.sudo = ["Bob", "rm"]
      self.user_logged_in = "Susan"
      self.user_logged_out = "Bob"
      self.user_logged_out = "Susan"
    end
  end
end

class AuditLog
  include LiveResource::Subscriber

  remote_subscription :user_logged_in, :login
  remote_subscription :user_logged_out, :logout
  remote_subscription :sudo # Implies method name

  def initialize(name)
    @backing_store = StringIO.new("", "r+")
    @audit_log = Logger.new(@backing_store)
    self.namespace = name
  end
  
  def login(user)
    @audit_log.info "User #{user} logged in"
  end
  
  def logout(user)
    @audit_log.info "User #{user} logged out"
  end
  
  def sudo(params)
    @audit_log.info "User #{params[0]} ran #{params[1]} as superuser"
  end
  
  def dump
    @backing_store.rewind
    @backing_store.readlines
  end
end

class AttributeSubscriberTest < Test::Unit::TestCase
  def setup
    Redis.new.flushall
  end
  
  def test_attribute_publishes_to_redis
    # Setting attribute should both send a set and publish to Redis.
    Redis.any_instance.expects(:set).once
    Redis.any_instance.expects(:publish).once
    
    UserLogin.new("foo").user_logged_in = "Bob"
  end
  
  def test_subscriber_receives_events
    login = UserLogin.new("users")
    audit_log = AuditLog.new("users")
    
    audit_log.subscribe
    login.start

    sleep 0.25
    audit_log.unsubscribe
    
    # This sequence should match what's in UserLogin.start
    audit_log = audit_log.dump
    assert_match "User Bob logged in", audit_log[0]
    assert_match "User Fred logged in", audit_log[1]
    assert_match "User Fred logged out", audit_log[2]
    assert_match "User Bob ran rm as superuser", audit_log[3]
    assert_match "User Susan logged in", audit_log[4]
    assert_match "User Bob logged out", audit_log[5]
    assert_match "User Susan logged out", audit_log[6]
  end
end
