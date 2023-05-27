# frozen_string_literal: true

class UpdateStatusStatWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 0

  def perform(status)
    Rails.logger.debug '>>>>>>>>>>>'
    FetchRemoteStatusService.new.call(status['uri'])
    Rails.logger.debug '>>>>>>>>>>>'
  rescue ActiveRecord::RecordNotFound
    true
  end
end
