require 'set'
require_relative 'remote_methods/dispatcher'

module LiveResource
  module RemoteMethods
    attr_reader :dispatcher

    def start
      if @dispatcher
        @dispatcher.start
      else
        @dispatcher = RemoteMethodDispatcher.new(self)
      end

      @dispatcher.wait_for_running
      self
    end

    def stop
      return if @dispatcher.nil?

      @dispatcher.stop
      self
    end

    def running?
      @dispatcher && @dispatcher.running?
    end

    def remote_methods
      if self.is_a? Class
        remote_singleton_methods
      else
        self.class.remote_instance_methods
      end
    end

    module ClassMethods
      def remote_instance_methods
        @remote_methods ||= Set.new

        # Filter private and protected methods
        @remote_methods.find_all do |m|
          if protected_method_defined?(m) or private_method_defined?(m)
            nil
          else
            m
          end
        end
      end

      def remote_singleton_methods
        @remote_singleton_methods ||= Set.new

        @remote_singleton_methods.find_all do |m|
          c = singleton_class
          if c.protected_method_defined?(m) or c.private_method_defined?(m)
            nil
          else
            m
          end
        end
      end

      def method_added(m)
        @remote_methods ||= Set.new
        @remote_methods << m
      end

      def singleton_method_added(m)
        @remote_singleton_methods ||= Set.new
        @remote_singleton_methods << m
      end
    end

#     # By default, all public methods of this class are remote callable.
#     def remote_methods
#       m = self.class.public_instance_methods
#       ancestors = self.class.ancestors.drop(1)
#
#       # Subtract methods inherited from our parent(s)
#       ancestors.each do |ancestor|
#         m = m - ancestor.public_instance_methods
#       end
#       m
#     end
  end
end

