# frozen_string_literal: true

class ForYouFeedWorker
  include Redisable
  include Sidekiq::Worker

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
      # TODO: Filter statuses before add to feed
      add_to_feed(@type, @list_id, @status)
    end
  end

  # Combine engagment actions. Greater than the min engagement set.
  # Check status for reblog content or assign original content
  # Reject statues with a reply_to or poll_id
  # Return the default limit
  def fetch_statuses
    filtered_statuses = list_statuses.select do |s|
      status = s.reblog? ? s.reblog : s
      status_counts = status.reblogs_count + status.replies_count + status.favourites_count
      status_counts >= MINIMUM_ENGAGMENT_ACTIONS && status.in_reply_to_id.nil? && status.poll_id.nil?
    end

    filtered_statuses.take((DEFAULT_STATUSES_LIST_LIMIT))
  end

  # MAMMOTH: Taken directly from FeedManager

  # Redis key of a feed
  # @param [Symbol] type
  # @param [Integer] id
  # @param [Symbol] subtype
  # @return [String]
  def key(type, id, subtype = nil)
    return "feed:#{type}:#{id}" unless subtype

    "feed:#{type}:#{id}:#{subtype}"
  end

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
    timeline_key = key(timeline_type, account_id)

    redis.zadd(timeline_key, status.id, status.id)
  end
end
