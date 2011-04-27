require 'logger'

module LiveResource
  module LogHelper
    def initialize_logger(logger = nil)
      return unless @logger.nil? # Don't double-init LogHelper
      
      @logger = logger
      
      if logger.nil?
        @logger = Logger.new(STDERR)
        @logger.level = Logger::WARN
      end
    end
    
    [:debug, :info, :warn, :error, :fatal].each do |level|
      define_method(level) do |*params|
        @logger.send(level, params.join(' '))
      end
    end
  end
end
