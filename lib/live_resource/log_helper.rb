require 'logger'

module LiveResource
  module LogHelper
    LOGLEVELS = [:debug, :warn, :info, :error, :fatal]

    def ignore_log?(level, str)
      ignore_log(level).any? { |ign| str.start_with?(ign) }
    end

    def ignore_log(level)
      @loghelper_ignores ||= LOGLEVELS.inject({}) do |h, level|
        ignores = ENV["LIVERESOURCE_#{level.to_s.upcase}_IGNORE"]
        h[level] = ignores ? ignores.split(":") : []
        h
      end

      @loghelper_ignores[level]
    end

    def logger
      @logger ||= nil
      if @logger.nil?
        @logger = Logger.new(STDERR)
        @logger.level = Logger::WARN
      end

      @logger
    end

    def logger=(logger)
      @logger = logger
    end

    LOGLEVELS.each do |level|
      define_method(level) do |*params|
        str = params.join(' ')
        return if self.ignore_log?(level, str)

        logger.send(level, str)
      end
    end
  end
end
