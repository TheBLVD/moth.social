# frozen_string_literal: true

class UpdateStatusStatWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 0

  def perform(_status)
    Rails.logger.debug '>>>>>>>>>>>'
    # UpdateStatusStatService.new.call(status)
    Rails.logger.debug 'DO THE THING'
    Rails.logger.debug '>>>>>>>>>>>'
  rescue ActiveRecord::RecordNotFound
    true
  end
end
