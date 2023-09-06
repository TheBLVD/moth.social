# frozen_string_literal: true

class Scheduler::ChannelStatusStatUpdateScheduler
  GO_BACK = 12 # number of hours back to fetch statuses

  # Get Statuses for the last n hours from all accounts of all channels
  # Iterate over and task a worker to fetch the status from original source
  # Update the Status Stat for boosted & likes for that status in the stat table
  include Sidekiq::Worker
  include JsonLdHelper
  include Async

  sidekiq_options retry: 0

  def perform
    update_channel_account_status_stat!
  end

  private

  #  Iterate over all statuses
  #  Pass {id,uri} to Update Worker
  def update_channel_account_status_stat!
    statuses_from_channel_accounts.each do |status|
      status_params = if status.reblog?
                        { id: status.reblog.id, uri: status.reblog.uri }
                      else
                        { id: status.id, uri: status.uri }
                      end
      UpdateStatusStatWorker.perform_async(status_params)
    end
  end

  def statuses_from_channel_accounts
    Status.where(account_id: accounts_list,
                 created_at: (GO_BACK.hours.ago)..Time.current)
  end

  # Get local account id's from channel accounts by username & domain
  # This account id's are specific to Moth.Social. AcctRelay doesn't know about
  # Returns an array of account id's
  def accounts_list
    channel_accounts = mammoth_channel_accounts.wait
    usernames = channel_accounts.pluck(:username)
    domains = channel_accounts.map { |a| a[:domain] == ENV['LOCAL_DOMAIN'] ? nil : a[:domain] }

    Account.where(username: usernames, domain: domains).pluck(:id)
  end

  # Fetch all accounts of all channels from AcctRelay
  # Bc we're updating statuses of accounts, the channel or channels they
  # belong to is not needed
  def mammoth_channel_accounts
    channels = Mammoth::Channels.new
    Async do
      channels.accounts
    end
  end
end
