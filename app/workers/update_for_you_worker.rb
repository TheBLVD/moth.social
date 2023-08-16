# frozen_string_literal: true

class UpdateForYouWorker
  include Redisable
  include Sidekiq::Worker

  sidekiq_options retry: 0, queue: 'pull'

  #  Fetch Acct Config from AcctRelay
  #  Fetch Following from AcctRelay
  #  Then status of those accounts from following locally
  #  Finally send them to for_you_feed_worker
  def perform(acct, options = {})
    @personal = PersonalForYou.new
    @acct = acct
    @user = mammoth_user(acct)
    @statuses = []
    # This is temperary
    @account = local_account

    # Unable to resolve account
    # Set Status to 'error'
    if @account.nil?
      update_user_status('error')
      ResolveAccountWorker.perform_async(@acct)
      return nil
    end

    # If rebuild is true, Zero Out User's for you feed
    personal_for_you.reset_feed(@account.id) if options[:rebuild] == true

    # Indirect Follow
    @statuses.append(indirect_following_status!)
    # Direct Follows
    @statuses.append(following_status!)
    # Public Feed

    # Pump all those statuses into through FeedWorker
    push_status!

    # Final Step:
    # Set user's status to 'idle'
    update_user_status('idle')
  end

  private

  def update_user_status(status)
    @personal.update_user(@acct, { status: status })
  end

  def local_account
    domain = @user[:domain] == ENV['LOCAL_DOMAIN'] ? nil : @user[:domain]
    Account.where(username: @user[:username], domain: domain).first
  end

  def mammoth_user(acct)
    @personal.user(acct)
  end

  # TODO: update account.id to user.acct
  # Return early if user setting is Zero, meaning 'off' from the iOS perspective
  def following_status!
    user_setting = @user[:for_you_settings]
    return if user_setting[:your_follows].zero?

    @personal.statuses_for_direct_follows(@acct)
             .filter_map { |s| engagment_threshold(s, user_setting[:your_follows], 'following') }
  end

  # Indirect Follows
  def indirect_following_status!
    user_setting = @user[:for_you_settings]
    return if user_setting[:friends_of_friends].zero?

    @personal.statuses_for_indirect_follows(@account)
             .filter_map { |s| engagment_threshold(s, user_setting[:friends_of_friends], 'indirect') }
  end

  def push_statuses!
    @statuses.map { |s| ForYouFeedWorker.new.perform(s['id'], @account.id, 'following') }
  end

  # Check status for User's level of engagment
  # Filter out polls and replys
  def engagment_threshold(wrapped_status, user_engagment_setting, type)
    # enagagment threshold
    engagment = engagment_metrics(type)
    status = wrapped_status.reblog? ? wrapped_status.reblog : wrapped_status

    status_counts = status.reblogs_count + status.replies_count + status.favourites_count
    status if status_counts >= engagment[user_engagment_setting] && status.in_reply_to_id.nil? && status.poll_id.nil?
  end

  # Threshold setttings variation for each specific branch of the for you feed
  # 1,2,3 relates to low,med, high and it's respectice value as it relates to engagment
  def engagment_metrics(type)
    case type
    when 'following'
      { 1 => 2, 2 => 4, 3 => 6 }
    when 'indirect', 'public'
      { 1 => 1, 2 => 2, 3 => 3 }
    end
  end
end
