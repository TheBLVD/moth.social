# frozen_string_literal: true

require 'http'
require 'json'
# V1 Channels updating statuses for unique channel feeds
class Scheduler::ChannelMammothStatusesScheduler
  GO_BACK = 2 # number of hours back to fetch statuses
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
    @channels = channels_with_statuses
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

  # Get all channels
  # Get accounts for each channel
  # process: filter by engagment and add cache set with channel_id key
  def channels_with_statuses
    mammoth_channels.wait.each do |channel|
      account_ids = account_ids(channel[:accounts])
      channel[:statuses] = statuses_from_channel_accounts(account_ids)
    end
  end

  def statuses_from_channel_accounts(account_ids)
    Status.where(account_id: account_ids,
                 created_at: (GO_BACK.hours.ago)..Time.current)
  end

  # Returns an array of account id's
  def account_ids(accounts)
    usernames = accounts.pluck(:username)
    domains = accounts.map { |a| a[:domain] == ENV['LOCAL_DOMAIN'] ? nil : a[:domain] }

    Account.where(username: usernames, domain: domains).pluck(:id)
  end

  # Fetch all accounts of all channels from AcctRelay
  # Bc we're getting statuses of particular channel accounts,
  # the channel or channels the accounts need to be associated to their channels
  def mammoth_channels
    channels = Mammoth::Channels.new
    Async do
      channels.list(include_accounts: true)
    end
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
