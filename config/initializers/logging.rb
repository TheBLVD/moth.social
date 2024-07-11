# frozen_string_literal: true

console_logger = ActiveSupport::Logger.new($stdout)
appsignal_logger = ActiveSupport::TaggedLogging.new(Appsignal::Logger.new('rails'))
# Rails.logger = console_logger.extend(ActiveSupport::Logger.broadcast(appsignal_logger))
