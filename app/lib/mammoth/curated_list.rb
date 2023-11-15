# frozen_string_literal: true

module Mammoth
  class CuratedList
    class NotFound < StandardError; end

    GO_BACK = 24 # number of hours back to fetch statuses
    FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
    LIST_TITLE = 'For You'

    def curated_list_statuses
      account_ids = mammoth_curated_accounts
      statuses_from_list(account_ids)
    end

    def statuses_from_list(account_ids)
      cache_key = 'mammoth_picks:statuses'
      Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
        Status.where(account_id: account_ids,
                     created_at: (GO_BACK.hours.ago)..Time.current).to_a
      end
    end

    def mammoth_curated_accounts
      cache_key = 'mammoth_picks:accounts'
      Rails.cache.fetch(cache_key, expires_in: 1.day) do
        owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT)
        @list = List.where(account: owner_account, title: LIST_TITLE).first!
        @list.list_accounts.pluck(:account_id).to_a
      end
    end
  end
end
