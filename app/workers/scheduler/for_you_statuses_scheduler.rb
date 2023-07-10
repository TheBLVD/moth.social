# frozen_string_literal: true

require 'http'
require 'json'

class Scheduler::ForYouStatusesScheduler
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
    owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT)
    @list = List.where(account: owner_account, title: LIST_TITLE).first!
    update_for_you_list!
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
