# frozen_string_literal: true

require 'http'
require 'json'

# Get accounts on beta list
# For each account get fedigraph of follows
# For each follow account get statuses and send to for_you_worker
class Scheduler::PersonalizedForYouStatusesScheduler
  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  BETA_FOR_YOU_LIST = 'Beta ForYou Personalized'

  include Sidekiq::Worker

  sidekiq_options retry: 0

  def perform
    personal_for_you = PersonalForYou.new
    personal_for_you.beta_list_accounts.each do |account|
      # Indirect Follows
      personal_for_you.statuses_for_indirect_follows(account).each do |status|
        ForYouFeedWorker.perform_async(status['id'], account.id, 'personal')
      end
    end
  end
end
