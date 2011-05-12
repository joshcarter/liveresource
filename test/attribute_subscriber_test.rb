require File.join(File.dirname(__FILE__), 'test_helper')

class UserLogin
  include LiveResource::Attribute
  
  remote_writer :user_logged_in
  remote_writer :user_logged_out
  
  def initialize(name)
    initialize_resource name
  end
  
  def start
    Thread.new do
      self.user_logged_in = "Bob"
      self.user_logged_in = "Fred"
      self.user_logged_out = "Fred"

      sleep 0.1

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
  def test_attribute_publishes_to_redis
    # Setting attribute should both send a set and publish to Redis.
    redis = Redis.new
    redis.expects(:set).once
    redis.expects(:publish).once
    Redis.expects(:new).returns(redis)
    
    rs = LiveResource::RedisSpace.new("mock")
    LiveResource::RedisSpace.expects(:new).returns(rs)
    
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
    assert_match "User Susan logged in", audit_log[3]
    assert_match "User Bob logged out", audit_log[4]
    assert_match "User Susan logged out", audit_log[5]
  end
end
