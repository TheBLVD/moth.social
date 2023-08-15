# frozen_string_literal: true

class UpdateForYouWorker
  include Redisable
  include Sidekiq::Worker

  sidekiq_options retry: 0, queue: 'pull'

  #  Fetch Acct Config from AcctRelay
  #  Fetch Following from AcctRelay
  #  Then status of those account from following
  #  Finally send them to for_you_feed_worker
  def perform(acct, _options = {})
    @acct = acct
    @user = mammoth_user(acct)
    # This is temperary
    @account = local_account
    if @account.nil?
      ResolveAccountWorker.perform_async(@acct)
      return nil
    end

    # Indirect Follow

    # Direct Follows
    push_following_status!
    # Public Feed
    # push_status!
  end

  private

  def local_account
    domain = @user[:domain] == ENV['LOCAL_DOMAIN'] ? nil : @user[:domain]
    Account.where(username: @user[:username], domain: domain).first
  end

  def mammoth_user(acct)
    PersonalForYou.new.user(acct)
  end

  # TODO: update account.id to user.acct
  # Return early if user setting is Zero, meaning 'off' from the iOS perspective
  def push_following_status!
    user_setting = @user[:for_you_settings]
    return if user_setting[:your_follows].zero?
    Rails.logger.debug { "ACCOUNT>>>>> #{@account}" }
    Rails.logger.debug { "USER>>>>> #{@user.inspect}" }
    PersonalForYou.new.statuses_for_direct_follows(@acct)
                  .filter_map { |s| engagment_threshold(s, user_setting[:your_follows]) }
                  .map { |s| ForYouFeedWorker.perform_async(s['id'], @account.id, 'following') }
  end

  # Check status for User's level of engagment
  # Filter out polls and replys
  def engagment_threshold(wrapped_status, user_engagment_setting)
    # follows enagagment threshold
    engagment = { 1 => 2, 2 => 4, 3 => 6 }
    status = wrapped_status.reblog? ? wrapped_status.reblog : wrapped_status

    status_counts = status.reblogs_count + status.replies_count + status.favourites_count
    status if status_counts >= engagment[user_engagment_setting] && status.in_reply_to_id.nil? && status.poll_id.nil?
  end
end
