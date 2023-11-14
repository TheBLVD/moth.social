# frozen_string_literal: true

# V1 of adding personalize statuses to a user's For You Feed
# Done by indiviual statuses and filtered. :foryou is the
# Mammoth curated list
class ChannelFeedManager
  include Singleton
  include Redisable

  MAX_ITEMS = 1000

  # Adds to Channel's Feed
  # We zip the statuses using the id for both the score of zadd and the value
  # Creating an array of array elements [["111296866514987736", "111296866514987736"]...
  def batch_to_feed(channel_id, status_ids)
    statuses = status_ids.zip(status_ids)

    perform_push_to_feed(channel_id, statuses)
  end

  # Adds to Channels Feed, but only those filtered
  # by the channels threshold
  # keeping both id and account_id of each status for breadcrumbs
  # we serialize it to json to store
  # Creating an array of array elements [["111296866514987736", "{"id":111409563649339301,"account_id":110481724616652677}"]...
  def batch_to_threshold(channel_id, statuses)
    batch_statuses = statuses.map { |s| [s[:id], Oj.dump(s)] }

    perform_push_to_threshold(channel_id, batch_statuses)
  end

  # Get statuses filtered by threshold
  # Serialize json string to hash
  # Return Array of Statuses [{:id:111409563649339301,:account_id:110481724616652677}...]
  def fetch_threshold_statuses(channel_id)
    channel_key = key(channel_id, true)

    redis.zrange(channel_key, 0, -1).map { |s| Oj.load(s, symbol_keys: true) }
  end

  private

  def perform_push_to_feed(channel_id, statuses)
    channel_key = key(channel_id)
    push(channel_key, statuses)
  end

  def perform_push_to_threshold(channel_id, statuses)
    channel_key = key(channel_id, true)
    push(channel_key, statuses)
  end

  # Do the acutal adding to redis
  def push(channel_key, statuses)
    redis.zadd(channel_key, statuses)
    # Keep the list from growning infinitely
    trim(channel_key)
  end

  # Trim a feed to maximum size by removing older items
  # @param [Integer] channel_key
  # @return [void]
  def trim(channel_key)
    # Remove any items past the MAX_ITEMS'th entry in our feed
    redis.zremrangebyrank(channel_key, 0, -(MAX_ITEMS + 1))
  end

  def key(channel_id, threshold = nil)
    return "feed:channel:#{channel_id}" unless threshold

    "feed:channel:threshold:#{channel_id}"
  end
end
