# frozen_string_literal: true

module Mammoth
  class Users
    class Error < StandardError; end

    ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}".freeze
    ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'

    def all_mammoth_users
      users
    end

    private

    def users
      current_page = 1
      total_pages = 1
      data = []
      while current_page <= total_pages
        response = fetch("https://#{ACCOUNT_RELAY_HOST}/api/v1/admin/users?page=#{current_page}")
        current_page = response['Current-Page'].to_i + 1
        total_pages = response['Total-Pages'].to_i
        raise Users::Error, "Request for users returned HTTP #{response.code}" unless response.code == 200

        page = JSON.parse(response.body).map(&:symbolize_keys).pluck(:acct)
        data.concat(page)
      end
      data
    rescue => e
      raise Users::Error, 'Unable to parse mammoth users from AcctRelay', e
    end

    def fetch(url)
      HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(url)
    end
  end
end
