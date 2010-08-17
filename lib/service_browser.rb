require 'rubygems'
require 'dnssd'
require 'service_info'

class ServiceBrowser
  def initialize(type, protocol = 'tcp')
    @type = ServiceInfo.new(:type => type, :protocol => protocol)
    @cache = Hash.new
    
    # Browse will call the block in a separate thread each time a
    # DNS-SD event is seen.
    @browser = DNSSD.browse(@type.type) do |reply|
      handle_browse_reply(reply)
    end
  end

  def trace(s)
    puts("  [dns-sd] #{s}") if false
  end

  def handle_browse_reply(reply)
    if ((reply.flags.to_i & DNSSD::Flags::Add) != 0)
      trace "add: #{reply.name}"

      # Kick off resolution of service name.
      DNSSD.resolve(reply.name, reply.type, reply.domain) do |reply|
        handle_resolve_reply(reply)
      end
    else
      trace "rmv: #{reply.name}"

      if reply.type == @type
        @cache[reply.name] = nil
      end
    end
  end

  def handle_resolve_reply(reply)
    trace "resolved #{reply.name}: #{reply.target}:#{reply.port}"
    
    @cache[reply.name] = ServiceInfo.new(
      :name => reply.name, 
      :type => @type,
      :protocol => @protocol,
      :host => reply.target,
      :port => reply.port)
  end

  def stop
    @browser.stop if @browser
  end

  def [](name)
    @cache[name]
  end
end
