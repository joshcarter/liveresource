require 'logger'

module LiveResource
  module LogHelper
    def logger
      if @logger.nil?
        @logger = Logger.new(STDERR)
        @logger.level = Logger::WARN
      end

      @logger
    end

    def logger=(logger)
      @logger = logger
    end

    [:debug, :info, :warn, :error, :fatal].each do |level|
      define_method(level) do |*params|
        logger.send(level, params.join(' '))
      end
    end
  end
end
