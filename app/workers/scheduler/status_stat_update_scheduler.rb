# frozen_string_literal: true

require 'http'
require 'json'

class Scheduler::StatusStatUpdateScheduler
  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  LIST_TITLE = 'For You'
  GO_BACK = 24 # number of hours back to fetch statuses

  # Get Statuses for the last n hours from the 'For You' list
  # Iterate over and task a worker to fetch the status from original source
  # Update the Status Stat for boosted & likes for that status
  include Sidekiq::Worker
  include JsonLdHelper

  sidekiq_options retry: 0

  def perform
    update_for_you_status_stat!
  end

  private

  def update_for_you_status_stat!
    statuses = statuses_from_list
    statuses.each do |status|
      UpdateStatusStatWorker.perform_async(status)
    end
  end

  def statuses_from_list
    Status.where(account_id: list_accounts, created_at: (GO_BACK.hours.ago)..Time.current).pluck(:id, :uri).map do |id, uri|
      { id: id, uri: uri }
    end
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
