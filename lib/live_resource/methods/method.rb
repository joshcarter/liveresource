require 'yaml'
require_relative 'token'

module LiveResource
  class RemoteMethod
    attr_reader :flags, :path
    attr_accessor :token

    def initialize(params)
      @path = params[:path]
      @token = params[:token]
      @flags = params[:flags] || {}

      if @path.nil?
        unless params[:method]
          raise ArgumentError.new("RemoteMethod must have a method")
        end

        @path = []
        @path << {
          :method => params[:method],
          :params => (params[:params] || []) }
      end
    end

    def method
      @path[0][:method]
    end

    def params
      @path[0][:params]
    end

    def params=(new_params)
      @path[0][:params] = new_params
    end

    def add_destination(proxy, method, params)
      @path << {
        :resource => proxy,
        :method => method,
        :params => params }
    end

    def next_destination!
      @path.shift
      @path[0][:resource]
    end

    def final_destination?
      @path.length == 1
    end

    def encode_with coder
      coder.tag = '!live_resource:method'
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
