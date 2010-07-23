require 'service_info'

module DnssdServer
  def initialize
    # Convert ancestor chain from CamelStyle to underscore_style
    type = self.class.to_s.gsub(/\B[A-Z]/, '_\&').downcase

    # Split into array of modules

    # Convert ancestor chain from module style to DNS-SD service type
    # i.e., foo::bar::baz becomes _baz._bar._foo
    type = type.split('::').reverse.join('._')

    @service = ServiceInfo.new(
      :name => 'Bob', # TODO: can probably do better than this
      :type => type,
      :protocol => 'tcp')
  end

  def dnssd_type
    @service.dnssd_type
  end
end

