# frozen_string_literal: true

require 'http'
require 'json'

class Scheduler::PersonalizedForYouStatusesScheduler
  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  BETA_FOR_YOU_LIST = 'Beta ForYou Personalized'

  # Get Statuses for the last n hours for a Personalized 'For You' Feed
  # Iterate over and task a worker to fetch the status from original source
  # Update the Status Stat for boosted & likes for that status
  include Sidekiq::Worker

  sidekiq_options retry: 0

  def perform
    # Get accounts on beta list
    # For each account get fedigraph of follows
    # For each follow account get statuses and send to for_you_worker
    personal_for_you = PersonalForYou.new
    personal_for_you.beta_list_accounts.each do |account|
      personal_for_you.statuses_for_indirect_follows(account).each do |status|
        ForYouFeedWorker.perform_async(status['id'], account.id, 'personal')
      end
    end
  end

  private

  def update_for_you_list!
    list_statuses.each do |status|
      ForYouFeedWorker.perform_async(status['id'], @list.id, 'foryou')
    end
  end

  def list_statuses
    list_feed.get(1000)
  end

  def list_feed
    ListFeed.new(@list)
  end
end
