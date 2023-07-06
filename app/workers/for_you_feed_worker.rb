# frozen_string_literal: true

class ForYouFeedWorker
  include Sidekiq::Worker

  def perform(status_id, id, type = 'personal', options = {})
    @type      = type.to_sym
    @status    = Status.find(status_id)
    @options   = options.symbolize_keys

    case @type
    when :personal
      @follower = Account.find(id)
    when :list
      @list     = List.find(id)
      @follower = @list.account
    end

    perform_push
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def perform_push
    case @type
    when :personal
      FeedManager.instance.push_to_home(@follower, @status, update: update?)
    when :list
      add_to_feed(@type, @list.id, @status)
    end
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
    reblog_key   = key(timeline_type, account_id, 'reblogs')

    if status.reblog? && (aggregate_reblogs.nil? || aggregate_reblogs)
      # If the original status or a reblog of it is within
      # REBLOG_FALLOFF statuses from the top, do not re-insert it into
      # the feed
      rank = redis.zrevrank(timeline_key, status.reblog_of_id)

      return false if !rank.nil? && rank < FeedManager::REBLOG_FALLOFF

      # The ordered set at `reblog_key` holds statuses which have a reblog
      # in the top `REBLOG_FALLOFF` statuses of the timeline
      if redis.zadd(reblog_key, status.id, status.reblog_of_id, nx: true)
        # This is not something we've already seen reblogged, so we
        # can just add it to the feed (and note that we're reblogging it).
        redis.zadd(timeline_key, status.id, status.id)
      else
        # Another reblog of the same status was already in the
        # REBLOG_FALLOFF most recent statuses, so we note that this
        # is an "extra" reblog, by storing it in reblog_set_key.
        reblog_set_key = key(timeline_type, account_id, "reblogs:#{status.reblog_of_id}")
        redis.sadd(reblog_set_key, status.id)
        return false
      end
    else
      # A reblog may reach earlier than the original status because of the
      # delay of the worker delivering the original status, the late addition
      # by merging timelines, and other reasons.
      # If such a reblog already exists, just do not re-insert it into the feed.
      return false unless redis.zscore(reblog_key, status.id).nil?

      redis.zadd(timeline_key, status.id, status.id)
    end

    true
  end
end
