require 'yaml'

module LiveResource
  class RemoteMethodToken
    attr_reader :redis_class, :redis_name, :seq

    def initialize(redis_class, redis_name, seq)
      @redis_class = redis_class
      @redis_name = redis_name
      @seq = seq
    end

    def encode_with coder
      coder.represent_scalar '!live_resource:token', "#{@redis_class}.#{@redis_name}.#{@seq}"
    end
  end
end

# Make YAML parser create Method objects from our custom type.
Psych.add_domain_type('live_resource', 'token') do |type, data|
  LiveResource::RemoteMethodToken.new(*(data.split '.'))
end
