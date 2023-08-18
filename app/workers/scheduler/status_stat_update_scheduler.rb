# frozen_string_literal: true

require 'http'
require 'json'

class Scheduler::StatusStatUpdateScheduler
  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  LIST_TITLE = 'For You'
  GO_BACK = 12 # number of hours back to fetch statuses

  # Get Statuses for the last n hours from the 'For You' list
  # Iterate over and task a worker to fetch the status from original source
  # Update the Status Stat for boosted & likes for that status
  include Sidekiq::Worker
  include JsonLdHelper

  sidekiq_options retry: 0

  def perform
    update_for_you_status_stat!
    update_personalized_for_you_status_stat!
  end

  private

  # Statuses from accounts on Public For You Feed
  def update_for_you_status_stat!
    statuses = statuses_from_list
    statuses.each do |status|
      status_params = if status.reblog?
                        { id: status.reblog.id, uri: status.reblog.uri }
                      else
                        { id: status.id, uri: status.uri }
                      end
      UpdateStatusStatWorker.perform_async(status_params)
    end
  end

  # Accounts from users fedigraph (array of account_id)
  # Status from those accounts 'created_at'
  def update_personalized_for_you_status_stat!
    statuses_from_personalized_for_you.each do |status|
      status_params = if status.reblog?
                        { id: status.reblog.id, uri: status.reblog.uri }
                      else
                        { id: status.id, uri: status.uri }
                      end
      UpdateStatusStatWorker.perform_async(status_params)
    end
  end

  # Statuses from all the 'indirect follows' from all the accounts on the beta list
  # Take the accounts from the beta list, get all the indirect follows
  def statuses_from_personalized_for_you
    personal_for_you = PersonalForYou.new
    personal_for_you.beta_list_accounts
                    .map { |account| personal_for_you.statuses_for_indirect_follows(account) }
                    .flatten
  end

  def statuses_from_list
    Status.where(account_id: list_accounts,
                 created_at: (GO_BACK.hours.ago)..Time.current)
  end

  def list_accounts
    ListAccount.where(list_id: list_for_you).select('account_id')
  end

  def list_for_you
    owner_account = set_owner
    List.where(account: owner_account, title: LIST_TITLE).select('id').first!
  end

  def set_owner
    Account.local.where(username: FOR_YOU_OWNER_ACCOUNT)
  end
end
