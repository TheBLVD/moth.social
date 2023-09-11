# frozen_string_literal: true

# V1 of Mammoth Channel Feeds
# Done by indiviual statuses and filtered. :foryou is the
# Mammoth curated list
class ChannelFeedWorker
  include Redisable
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 0

  MAX_ITEMS = 1000

  def perform(status_id, id, options = {})
    @status_id  = status_id
    @channel_id = id
    @options = options.symbolize_keys

    # perform_push_to_feed
    Rails.logger.debug { "CHANNELFEED_WORKER>>>>>>> #{@status_id.inspect}" }

    add_to_feed!
  end

  private

  # MAMMOTH: Taken directly from FeedManager

  # Adds a status to an channel's feed, returning true if a status was
  # added, and false if it was not added to the feed. Note that this is
  # an internal helper: callers must call trim or push updates if
  # either action is appropriate.
  # @param [Integer] channel_id
  # @param [Status] status_id
  # @return [Boolean]
  def add_to_feed!
    timeline_type = 'channel'
    timeline_key = FeedManager.instance.key(timeline_type, @channel_id)

    redis.zadd(timeline_key, @status_id, @status_id)

    # Keep the list from growning infinitely
    trim(timeline_key)
  end

  # Trim a feed to maximum size by removing older items
  # @param [Symbol] type
  # @param [Integer] timeline_id
  # @return [void]
  def trim(timeline_key)
    # Remove any items past the MAX_ITEMS'th entry in our feed
    redis.zremrangebyrank(timeline_key, 0, -(MAX_ITEMS + 1))
  end
end
