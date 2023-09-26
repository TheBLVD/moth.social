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

    def mammoth_curated_accounts
      owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT)
      @list = List.where(account: owner_account, title: LIST_TITLE).first!
      @list.list_accounts.pluck(:account_id)
    end

    def statuses_from_list(account_ids)
      Status.where(account_id: account_ids,
                   created_at: (GO_BACK.hours.ago)..Time.current)
    end
  end
end
