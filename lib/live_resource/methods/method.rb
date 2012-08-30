require 'yaml'

module LiveResource
  class RemoteMethod
    attr_reader :method, :params, :flags, :path
    attr_accessor :token

    def initialize(params)
      @method = params[:method]
      @params = params[:params] || []
      @flags = params[:flags] || {}
      @path = params[:path] || []
      @token = params[:token]

      if @method.nil?
        raise ArgumentError.new("RemoteMethod must have a method")
      end
    end

    def << (proxy)
      @path << proxy
    end

    def destination
      @path.first
    end

    def next_destination
      @path.shift
    end

    def encode_with coder
      coder.tag = '!live_resource:method'
      coder['method'] = @method
      coder['params'] = @params
      coder['flags'] = @flags
      coder['path'] = @path
      coder['token'] = @token if @token
    end
  end
end

# Make YAML parser create Method objects from our custom type.
Psych.add_domain_type('live_resource', 'method') do |type, data|
  # Convert string keys to symbols
  data = Hash[data.map { |k,v| [k.to_sym, v] }]

  LiveResource::RemoteMethod.new(data)
end
