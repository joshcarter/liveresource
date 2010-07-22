require 'rubygems'
require 'test/unit'
require 'mocha'
require 'resource'

module Resource
  class Fan

    # TODO: should have some helper for the caller which checks if the header
    # says the response is not done, throws an exception if it's done but
    # has an error, etc..

    # TODO: need to respond with IN_PROGRESS if we could block while trying to
    # fulfill the request

    # TODO: how do I publish the status when I know via some other means that
    # it has changed?

    # TODO: need something here that automatically sends the response returned
    # from this method
    def status(request = nil)
      response = Resource::FanStatus.new
      response.header.status = Resource::ResponseHeader::DONE
      response.status = Resource::Status::OK
      response.tach = 1000
      response
    end
  end
end

class CompilerTest < Test::Unit::TestCase
  def test_get_status
    threads = Array.new

    threads << Thread.new do


    end


    ctx = ZMQ::Context.new(1)
    s = ctx.socket(ZMQ::PUB);
    s.connect("tcp://127.0.0.1:5555")

  end
end
