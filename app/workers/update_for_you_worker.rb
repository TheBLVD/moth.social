# frozen_string_literal: true

class UpdateForYouWorker
  include Redisable
  include Sidekiq::Worker

  sidekiq_options retry: 0

  #  Fetch Acct Config from AcctRelay
  #  Fetch Following from AcctRelay
  #  Then status of those account from following
  #  Finally send them to for_you_feed_worker
  def perform(acct, _options = {})
    @acct = acct
    @user = mammoth_user(acct)
    Rails.logger.debug { "UPDATEFORYOU::#{@user['acct']} >> #{@user.inspect}" }
    # Account Prefereces here
    @user_min_engagment = 0
    # Indirect Follow

    # Direct Follows
    push_following_status!
    # Public Feed
    # push_status!
  end

  private

  def user_following(acct)
    PersonalForYou.new.user_following(acct)
  end

  def mammoth_user(acct)
    PersonalForYou.new.user(acct)
  end

  def push_following_status!
    PersonalForYou.new.statuses_for_direct_follows(@acct)
                  .filter_map { |s| engagment_threshold(s) }
                  .map { |s| ForYouFeedWorker.perform_async(s['id'], @acct, 'following') }
  end

  def engagment_threshold(wrapped_status)
    status = wrapped_status.reblog? ? wrapped_status.reblog : wrapped_status

    status_counts = status.reblogs_count + status.replies_count + status.favourites_count
    status if status_counts >= @user_min_engagment && status.in_reply_to_id.nil? && status.poll_id.nil?
  end
end
