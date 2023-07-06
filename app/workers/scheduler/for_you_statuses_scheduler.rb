# frozen_string_literal: true

require 'http'
require 'json'

class Scheduler::ForYouStatusesScheduler
  DEFAULT_STATUSES_LIST_LIMIT = 240
  MINIMUM_ENGAGMENT_ACTIONS = 2

  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  LIST_TITLE = 'For You'
  BETA_FOR_YOU_LIST = 'Beta ForYou Personalized'

  # Get Statuses for the last n hours from the 'For You' list
  # Iterate over and task a worker to fetch the status from original source
  # Update the Status Stat for boosted & likes for that status
  include Sidekiq::Worker
  include JsonLdHelper

  sidekiq_options retry: 0

  def perform
    update_for_you_list!
  end

  private

  def update_for_you_list!
    owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT)
    @list = List.where(account: owner_account, title: LIST_TITLE).first!
    @statuses = fetch_statuses
    @statues.each do |status|
      ForYouFeedWorker.perform_async(status.id, @list.id, 'list')
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

  def list_statuses
    list_feed.get(1000)
  end

  def list_feed
    ListFeed.new(@list)
  end

  #   def deliver_to_all_followers!
  #     @account.followers_for_local_distribution.select(:id).reorder(nil).find_in_batches do |followers|
  #       FeedInsertWorker.push_bulk(followers) do |follower|
  #         [@status.id, follower.id, 'home', { 'update' => update? }]
  #       end
  #     end
  #   end
end
