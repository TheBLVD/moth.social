# frozen_string_literal: true

# V1 of adding personalize statuses to a user's For You Feed
# Done by indiviual statuses and filtered. :foryou is the
# Mammoth curated list
class ForYouFeedManager
  include Singleton
  include Redisable

  MAX_ITEMS = 1000
  MINIMUM_ENGAGMENT_ACTIONS = 2

  # Adds to Account's For You Feed
  # We zip the statuses using the id for both the score of zadd and the value
  # Creating an array of array elements [["111296866514987736", "111296866514987736"]...
  def batch_to_feed(account_id, status_ids)
    statuses = status_ids.zip(status_ids)

    perform_push_to_feed(account_id, statuses)
  end

  private

  def perform_push_to_feed(account_id, statuses)
    foryou_key = key(account_id)
    redis.zadd(foryou_key, statuses)

    # Keep the list from growning infinitely
    trim(foryou_key)
  end

  # Trim a feed to maximum size by removing older items
  # @param [Integer] foryou_key
  # @return [void]
  def trim(foryou_key)
    # Remove any items past the MAX_ITEMS'th entry in our feed
    redis.zremrangebyrank(foryou_key, 0, -(MAX_ITEMS + 1))
  end

  def key(account_id)
    FeedManager.instance.key('personal', account_id)
  end
end
