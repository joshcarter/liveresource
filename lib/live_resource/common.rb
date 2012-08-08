require File.join(File.dirname(__FILE__), 'log_helper')
require File.join(File.dirname(__FILE__), 'redis_client')

module LiveResource
  module Common
    # Class-level redis class name
    def self.redis_class
      "#{redisized_key(self.to_s)}-class"
    end

    # Instance-level redis class name
    def redis_class
      redisized_key(self.class.to_s)
    end

    # Class-level redis object name
    def self.redis_name
      @hostname ||= `hostname`

      "#{redis_class}.#{@hostname}.#{Process.pid}"
    end

    # Instance-level redis object name
    def redis_name
      redisized_key(obj.resource_name)
    end

    def redis_name_and_class(obj)
      redis_name = nil
      redis_class = redisized_key(obj.to_s)

      if obj.is_a? Class
        redis_class << "-class"
        redis_name = "#{redis_class}.#{host_pid}"
      else
        redis_name = redisized_key(obj.resource_name)
      end

      [redis_name, redis_class]
    end

    def redisized_key(word)
      word = word.to_s.dup
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.gsub!('::', '-')
      word.downcase!
      word
    end
  end
end
