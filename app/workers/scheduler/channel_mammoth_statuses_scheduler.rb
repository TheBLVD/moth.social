# frozen_string_literal: true

require 'http'
require 'json'
# V1 Channels updating statuses for unique channel feeds
class Scheduler::ChannelMammothStatusesScheduler
  MINIMUM_ENGAGMENT_ACTIONS = 0

  # Get Statuses for the last n hours from all channels
  # Iterate over and task a worker to fetch the status from original source
  include Sidekiq::Worker
  include JsonLdHelper
  include Async

  sidekiq_options retry: 0

  def perform
    update_channel_feeds!
  end

  private

  # Get statuses for accounts of each channel
  # FeedWorker w/ status_id & channel_id will add status
  def update_channel_feeds!
    @channels = Mammoth::Channels.new.channels_with_statuses
    @channels.each do |channel|
      Rails.logger.info { "CHANNEL::  #{channel} \n" }
      push_statuses(channel[:statuses], channel[:id])
    end
  end

  # Filter statuses based on engagment and push to feed.
  def push_statuses(statuses, channel_id)
    statuses.filter_map { |status| engagment_threshold(status) }
            .each { |status| ChannelFeedWorker.perform_async(status['id'], channel_id) }
  end

  # Check status for Channel level of engagment
  # Filter out polls and replys
  def engagment_threshold(wrapped_status)
    # enagagment threshold
    engagment = MINIMUM_ENGAGMENT_ACTIONS
    status = wrapped_status.reblog? ? wrapped_status.reblog : wrapped_status

    status_counts = status.reblogs_count + status.replies_count + status.favourites_count
    status if status_counts >= engagment && status.in_reply_to_id.nil? && status.poll_id.nil?
  end
end
