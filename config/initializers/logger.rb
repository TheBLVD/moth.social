# Use AppSignal's logger and a STDOUT logger
console_logger = ActiveSupport::Logger.new(STDOUT)
appsignal_logger = ActiveSupport::TaggedLogging.new(Appsignal::Logger.new('rails'))
Rails.logger = console_logger.extend(ActiveSupport::Logger.broadcast(appsignal_logger))
