require 'rubygems'
require 'protobuf/message/message'
require 'protobuf/message/enum'
require 'protobuf/message/service'
require 'protobuf/message/extend'
require 'protobuf/compiler/compiler'
require 'pp'

module Protobuf
  module Visitor
    class CreateRpcVisitor < Base

      #
      # Override existing create_files so we create stub classes with the
      # correct methods instead of creating files with gunk in them.
      #
      def create_files(message_file, out_dir, create_file=true)
        @services.each do |service_name, rpcs|
          message_module = package.map{|p| Util.camelize(p.to_s)}.join('::')

          # Create Package::Service::Stub heirarchy. Note that package 
          # module already exists by the time we get here.
          message_module = Object::const_get(message_module)
          service_module = message_module::const_set(service_name, Module.new)
          service_class = service_module::const_set("Stub", Class.new)

          rpcs.each do |name, request, response|
            service_class.class_eval do
              define_method(Util.underscore(name)) do
                "yo"
              end
            end
          end
        end
      end # create_files
    end # CreateRpcVisitor
  end # Visitor
end # ProtoBuf

#
# This class ensures we only compile the protocol buffer file once.
#
class DynamicCompiler
  @@already_compiled = false

  def self.compile(file)
    return if @@already_compiled

    Protobuf::Compiler.new.compile(file, '.', '.', false)
    @@already_compiled = true
  end
end

DynamicCompiler.compile(File::join(File::dirname(__FILE__), "resource.proto"))
