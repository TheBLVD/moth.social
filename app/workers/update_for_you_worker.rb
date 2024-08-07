# frozen_string_literal: true

class UpdateForYouWorker
  include Redisable
  include Sidekiq::Worker
  LOAD_TEST_MULTIPLIER = ENV['FOR_YOU_LOAD_TEST_MULTIPLIER'].to_i || 1

  sidekiq_options retry: 0, queue: 'mammoth_default'

  # Mammoth Curated List(OG List)

  #  Fetch Acct Config from AcctRelay
  #  Fetch Following from AcctRelay
  #  Then status of those accounts from following locally
  #  Finally send them to for_you_feed_worker
  def perform(opts)
    @personal = PersonalForYou.new
    @acct = opts['acct']
    @user = mammoth_user(@acct).wait

    if @user[:acct].nil?
      update_user_status('error').wait
      return nil
    end

    # If rebuild is true, Zero Out User's for you feed
    @personal.reset(@user[:acct]) if opts['rebuild']

    @statuses = filter_statuses!

    foryou_manager.batch_to_feed(@user[:acct], @statuses)
    # Final Step:
    # Set user's status to 'idle'
    update_user_status('idle').wait
  end

  private

  # Channel Feeds Enabled
  # Mammoth Curated OG Feed (Mammoth Picks)
  # Indirect Follow (Personalization)
  # Direct Follows Trending (Personalization)
  def filter_statuses!
    Rails.logger.warn "UPDATEFORYOUWORKER LOAD TEST:: x#{LOAD_TEST_MULTIPLIER}" if LOAD_TEST_MULTIPLIER > 1
    # For load testing. Only run Publicly available filters.
    # Indirect & Following are in closed beta not enabled to the public. Yet.
    if LOAD_TEST_MULTIPLIER > 1
      [*channels_status, *mammoth_curated_status]
    else
      [*indirect_following_status, *following_status, *channels_status, *mammoth_curated_status]
    end
  end

  def update_user_status(status)
    Async do
      @personal.update_user(@acct, { status: status })
    end
  end

  def mammoth_user(acct)
    Async do
      @personal.user(acct)
    end
  end

  # TODO: update account.id to user.acct
  # Return early if user setting is Zero, meaning 'off' from the iOS perspective
  def following_status
    user_setting = @user[:for_you_settings]
    return if user_setting[:your_follows].zero? || user_setting[:type] == 'public'

    origin = Mammoth::StatusOrigin.instance
    statuses = @personal.statuses_for_direct_follows(@user[:acct])
                        .filter_map { |s| engagment_threshold(s, user_setting[:your_follows], 'following') }

    origin.bulk_add_trending_follows(statuses, @user)
    statuses.pluck(:id)
  end

  # Indirect Follows
  def indirect_following_status
    user_setting = @user[:for_you_settings]
    return if user_setting[:friends_of_friends].zero? || user_setting[:type] == 'public'

    origin = Mammoth::StatusOrigin.instance
    statuses = @personal.statuses_for_indirect_follows(@user[:acct])
                        .filter_map { |s| engagment_threshold(s, user_setting[:friends_of_friends], 'indirect') }

    origin.bulk_add_friends_of_friends(statuses, @user)
    statuses.pluck(:id)
  end

  # Channels Subscribed
  # Include ONLY enabled_channels
  def channels_status
    user_setting = @user[:for_you_settings]
    return if user_setting[:from_your_channels].zero?

    @personal.statuses_for_enabled_channels(@user).pluck(:id)
  end

  # Mammoth Curated OG List
  def mammoth_curated_status
    user_setting = @user[:for_you_settings]
    return if user_setting[:curated_by_mammoth].zero?

    curated_list = Mammoth::CuratedList.new
    origin = Mammoth::StatusOrigin.instance

    list_statuses = curated_list.curated_list_statuses
    origin.bulk_add_mammoth_pick(list_statuses, @user)
    list_statuses.pluck(:id)
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
    when 'following', 'mammoth'
      { 1 => 4, 2 => 6, 3 => 8 }
    when 'indirect'
      { 1 => 1, 2 => 2, 3 => 3 }
    end
  end

  def foryou_manager
    ForYouFeedManager.instance
  end
end
