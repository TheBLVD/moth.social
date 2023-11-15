# frozen_string_literal: true

module Mammoth
  class CuratedList
    class NotFound < StandardError; end

    GO_BACK = 24 # number of hours back to fetch statuses
    FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
    LIST_TITLE = 'For You'
    ENGAGMENT_THRESHOLD = 4

    def curated_list_statuses
      account_ids = mammoth_curated_accounts
      statuses_from_list(account_ids)
    end

    # Get Statuses from Mammoth Pick's list
    # Filter using engagment threshold
    # only return id and account_id for breadcrumbs
    # This is constantly updating, cache for only a couple minutes
    def statuses_from_list(account_ids)
      cache_key = 'mammoth_picks:statuses'
      Rails.cache.fetch(cache_key, expires_in: 120.seconds) do
        statuses = Status.where(account_id: account_ids,
                                created_at: (GO_BACK.hours.ago)..Time.current).to_a

        statuses.filter_map { |s| engagment_threshold(s) }.pluck(:id, :account_id).map { |id, account_id| { id: id, account_id: account_id } }
      end
    end

    # Accounts on the Mammoth Pick's List
    # These are rarely chanaged
    def mammoth_curated_accounts
      cache_key = 'mammoth_picks:accounts'
      Rails.cache.fetch(cache_key, expires_in: 1.day) do
        owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT)
        @list = List.where(account: owner_account, title: LIST_TITLE).first!
        @list.list_accounts.pluck(:account_id).to_a
      end
    end

    private

    # Check status for Set Engagment
    # Filter out polls and replys
    def engagment_threshold(wrapped_status)
      # enagagment threshold
      status = wrapped_status.reblog? ? wrapped_status.reblog : wrapped_status

      status_counts = status.reblogs_count + status.replies_count + status.favourites_count
      status if status_counts >= ENGAGMENT_THRESHOLD && status.in_reply_to_id.nil? && status.poll_id.nil?
    end
  end
end
