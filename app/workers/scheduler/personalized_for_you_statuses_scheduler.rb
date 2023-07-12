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
    Rails.logger.debug 'Scheduler::PersonalizedForYouStatusesScheduler>>>>>>>>'
    # Get accounts on beta list
    # For each account get fedigraph of follows
    # For each follow account get statuses and send to for_you_worker
    for_you_personalized_beta_list_accounts.each do |account|
      statuses_for_indirect_follows(account).each do |status|
        ForYouFeedWorker.perform_async(status['id'], account.id, 'personal')
      end
    end
  end

  private

  def for_you_personalized_beta_list_accounts
    default_owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT).first!
    beta_list = List.where(account: default_owner_account, title: BETA_FOR_YOU_LIST).first!
    beta_list.accounts.without_suspended.includes(:account_stat)
  end

  # Indirect Follows are the following of your followers
  # IE Friends of Friends
  def statuses_for_indirect_follows(account)
    # Get Fedi Accounts
    Rails.logger.debug { "ACCOUNT>>>>> #{account.inspect}" }
    account_handle = account.local? ? account.local_username_and_domain : account.acct
    cache_key = "follow_recommendations:#{account_handle}"
    fedi_account_handles = Rails.cache.fetch(cache_key)
    Rails.logger.debug { "CACHE_VALUE:: #{fedi_account_handles}" }
    # Get Account id's for all of them
    username_query = Array.[]
    domain_query = Array.[]
    fedi_account_handles.each do |handle|
      h = handle.split('@')
      username_query.push(h[0])
      domain_query.push(h[1])
    end
    # Array of account id's
    account_ids = Account.where(username: username_query, domain: domain_query).pluck(:id)
    Rails.logger.info { "ACCOUNT_IDS>>>>>> #{account_ids.inspect}" }
    # Get Statuses for those accounts
    Status.where(account_id: account_ids, updated_at: 12.hours.ago..Time.now).limit(200)
  end

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
