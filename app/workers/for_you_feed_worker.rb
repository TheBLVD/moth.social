# frozen_string_literal: true

class ForYouFeedWorker
  include Redisable
  include Sidekiq::Worker

  MAX_ITEMS = 1000
  MINIMUM_ENGAGMENT_ACTIONS = 2

  def perform(status_id, id, type = 'personal', options = {})
    @type      = type.to_sym
    @status    = Status.find(status_id)
    @options   = options.symbolize_keys

    case @type
    when :personal
      @follower = Account.find(id)
    when :foryou
      @list_id = id
    end
    perform_push_to_feed
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def perform_push_to_feed
    case @type
    when :foryou
      if filter_from_feed?(@status)
        add_to_feed(@type, @list_id, @status)
      end
    end
  end

  # Check if status should not be added to the list feed
  # Combine engagment actions. Greater than the min engagement set.
  # Check status for reblog content or assign original content
  # Reject statues with a reply_to or poll_id
  # @param [Status] status
  # @param [List] list
  # @return [Boolean]
  def filter_from_feed?(wrapped_status)
    status = wrapped_status.reblog? ? wrapped_status.reblog : wrapped_status
    status_counts = status.reblogs_count + status.replies_count + status.favourites_count

    status_counts >= MINIMUM_ENGAGMENT_ACTIONS && status.in_reply_to_id.nil? && status.poll_id.nil?
  end

  # MAMMOTH: Taken directly from FeedManager

  # Adds a status to an account's feed, returning true if a status was
  # added, and false if it was not added to the feed. Note that this is
  # an internal helper: callers must call trim or push updates if
  # either action is appropriate.
  # @param [Symbol] timeline_type
  # @param [Integer] account_id
  # @param [Status] status
  # @param [Boolean] aggregate_reblogs
  # @return [Boolean]
  def add_to_feed(timeline_type, account_id, status, aggregate_reblogs: true)
    timeline_key = FeedManager.instance.key(timeline_type, account_id)

    redis.zadd(timeline_key, status.id, status.id)

    # Keep the list from growning infinitely
    trim(timeline_key, account_id)
  end

  # Trim a feed to maximum size by removing older items
  # @param [Symbol] type
  # @param [Integer] timeline_id
  # @return [void]
  def trim(type, timeline_id)
    timeline_key = FeedManager.instance.key(type, timeline_id)

    # Remove any items past the MAX_ITEMS'th entry in our feed
    redis.zremrangebyrank(timeline_key, 0, -(MAX_ITEMS + 1))
  end
end
