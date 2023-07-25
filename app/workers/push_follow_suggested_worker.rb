# frozen_string_literal: true

class PushFollowSuggestedWorker
  include Sidekiq::Worker
  include Async

  sidekiq_options queue: 'pull', retry: 0

  def perform(handle)
    @handle = handle
    recommended_accounts = suggested_accounts.wait
    Rails.logger.info { "ACCOUNT ADDED>>>>>>>>RECOMMENDED: #{recommended_accounts}" }
    AccountRelayService.new.call(handle, recommended_accounts)
  end

  private

  def suggested_accounts
    Async do
      FollowRecommendationsService.new.call(handle: @handle, force: true)
    end
  end
end
