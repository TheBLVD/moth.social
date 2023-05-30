# frozen_string_literal: true

class UpdateStatusStatWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 0

  def perform(status)
    UpdateStatusStatService.new.call(status)
  end
end
