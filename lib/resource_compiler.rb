require 'rubygems'
require 'protobuf/message/message'
require 'protobuf/message/enum'
require 'protobuf/message/service'
require 'protobuf/message/extend'
require 'protobuf/compiler/compiler'
require 'pp'
require 'dnssd_server'

#
# Override create_files in each of the Message and RPC handlers so they
# create modules/classes in this Ruby process rather than generate .rb
# files. This allows us to run against the .proto files directly without
# the intermediate rprotoc compilation step.
#

module Protobuf
  module Visitor
    class CreateMessageVisitor < Base
      def create_files(filename, _1, _2)
        # TODO: probably a better way to do this (like RpcVisitor below)
        eval(to_s, TOPLEVEL_BINDING)
        
        # puts "CreateMessageVisitor.create_files:"
        # puts to_s
      end
    end
  end
end

module Protobuf
  module Visitor
    class CreateRpcVisitor < Base
      def create_files(message_file, _1, _2)
        @services.each do |service_name, rpcs|

          #
          # Dig through a package name like foo.bar.baz and create nested
          # modules Foo::Bar::Baz as needed.
          #

          # This list contains: "Foo", "Bar", "Baz"
          module_names = package.map{ |p| Util.camelize(p.to_s) }

          # This list will contain: Foo (the module), Foo::Bar, Foo::Bar::Baz
          modules = Array.new

          module_names.each do |m|
            begin
              parent = modules.empty? ? Object : modules.last
              modules << parent::const_get(m)

              # puts "Module #{m} already exists under parent #{parent}"
            rescue NameError
              # Module does not yet exist; create it
              modules[-1]::const_set(m, Module.new)
              modules << modules.last::const_get(m)

              # puts "Created module #{m} under parent #{modules[-2]}"
            end
          end

          service_class = modules.last.const_set(service_name, Class.new)
          # puts "Created class #{service_class} under parent #{modules.last}"
          
          # Service classes need dnssd module
          service_class.class_eval { include DnssdServer }

          rpcs.each do |name, request, response|
            name = Util.underscore(name)
            
            service_class.class_eval do
              define_method(name) do
                raise NotImplementedError.new("client must override this method")
              end

              # puts "Defined method #{name} under class #{service_class}"
            end
          end
        end
      end # create_files
    end # CreateRpcVisitor
  end # Visitor
end # ProtoBuf

class ResourceCompiler
  @@compiled_protos = Array.new

  def self.compile(file)
    file += ".proto"

    # See if we've already compiled this proto
    stat = File::Stat.new(file)
    if @@compiled_protos.include?(stat)
      return false
    else
      @@compiled_protos << stat
    end

    Protobuf::Compiler.new.compile(File::basename(file), File::dirname(file), '', false)
    return true
  end
end

def require_resource(file)
  ResourceCompiler::compile(file)
end
