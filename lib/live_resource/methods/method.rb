module LiveResource
  class RemoteMethod
    def initialize(method, params, flags, path = [])
      @method = method
      @params = params
      @flags = flags
      @path = path
    end

    def << (proxy)
      @path << proxy
    end

    def destination
      @path.first
    end

    def shift
      @path.shift
    end

    def encode_with coder
      coder.tag = '!live_resource:method'
      coder['method'] = @method
      coder['params'] = @params
      coder['flags'] = @flags
      coder['path'] = @path
    end
  end
end

# Make YAML parser create Method objects from our custom type.
Psych.add_domain_type('live_resource', 'method') do |type, val|
  LiveResource::RemoteMethod.new(
                             val['method'],
                             val['params'],
                             val['flags'],
                             val['path'])
end
