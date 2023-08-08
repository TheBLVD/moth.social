# frozen_string_literal: true

class UpdateForYouWorker
  include Redisable
  include Sidekiq::Worker

  #  Fetch Acct Config from AcctRelay
  #  Fetch Following from AcctRelay
  #  Then status of those account from following
  #  Finally send them to for_you_feed_worker
  def perform(acct, _options = {})
    @acct = acct
    Rails.logger.debug { "UPDATEFORYOU:: #{@acct}" }
    # Account Prefereces here
    # Indirect Follow

    # Direct Follows
    # Public Feed
    # push_status!
  end

  private

  def fetch_user_following; end

  def push_status!
    personal_for_you.statuses_for_direct_follows(@account).each do |status|
      ForYouFeedWorker.perform_async(status['id'], account.id, 'personal')
    end
  end
end
