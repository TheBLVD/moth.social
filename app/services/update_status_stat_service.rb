# frozen_string_literal: true

class UpdateStatusStatService < BaseService
  include Redisable
  include LanguagesHelper

  class NoChangesSubmittedError < StandardError; end

  # @param [Status] status
  # @param [Hash] options
  def call(status_uri, _options = {})
    # Fetch status from source
    # Look up StatusStat by id
    # Update attributes with new data
    # StatusStat.transaction do
    #   update_immediate_attributes!
    # end

    Rails.logger.debug 'DO THE SERVICE'
    FetchRemoteStatusService.new.call(status_uri)
  end
end
