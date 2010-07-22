require 'rubygems'
require 'test/unit'
require 'mocha'
require 'resource'

class CompilerTest < Test::Unit::TestCase
  def test_compile_generates_correct_classes_and_methods
    progress_response = Resource::Response.new
    progress_response.id = 0
    progress_response.status = Resource::Response::Status::IN_PROGRESS

    done_response = Resource::Response.new
    done_response.id = 0
    done_response.status = Resource::Response::Status::OK
    done_response.value = "alive"

    fan = Resource::Fan::Stub.new

    # Fan should have status method already
    assert(fan.methods.include? "status")

    fan.expects(:status).times(3).returns(progress_response, progress_response, done_response)

    loop do
      response = fan.status

      next if (response.status == Resource::Response::Status::IN_PROGRESS)

      assert_equal("alive", response.value)
      break
    end
  end
end

