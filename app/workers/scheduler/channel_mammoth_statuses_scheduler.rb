# frozen_string_literal: true

require 'http'
require 'json'
# V1 Channels updating statuses for unique channel feeds
class Scheduler::ChannelMammothStatusesScheduler
  MINIMUM_ENGAGMENT_ACTIONS = 0

  # Get Statuses for the last n hours from all channels
  # Iterate over and task a worker to fetch the status from original source
  include Sidekiq::Worker
  include Async

  sidekiq_options retry: 0

  def perform
    update_channel_feeds!
    update_engagement_threshold_channel_feeds!
  end

  private

  # Get statuses for accounts of each channel
  # ChannelManagerFeed status_id & channel_id will add status in a batch
  def update_channel_feeds!
    channels = Mammoth::Channels.new.channels_with_statuses
    channels.each do |channel|
      Rails.logger.debug { "CHANNEL::  #{channel} \n" }
      channel_feed_manager.batch_to_feed(channel[:id], channel[:statuses])
    end
  end

  def update_engagement_threshold_channel_feeds!
    filtered_channels = Mammoth::Channels.new.filter_statuses_with_threshold
    filtered_channels.each do |channel|
      Rails.logger.debug { "FILTER CHANNEL::  #{channel} \n" }
      channel_feed_manager.batch_to_threshold(channel[:id], channel[:statuses])
    end
  end

  def channel_feed_manager
    ChannelFeedManager.instance
  end
end
