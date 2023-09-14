# frozen_string_literal: true
module Mammoth
  class Channels
    class NotFound < StandardError; end

    GO_BACK = 2 # number of hours back to fetch statuses
    ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}"
    ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'

    # Get all channels
    # Get accounts for each channel
    # process: filter by engagment and add cache set with channel_id key
    def channels_with_statuses
      list(include_accounts: true).each do |channel|
        account_ids = account_ids(channel[:accounts])
        channel[:statuses] = statuses_from_channel_accounts(account_ids)
      end
    end

    def select_channels_with_statuses(channels)
      channels.each do |channel|
        account_ids = account_ids(channel[:accounts])
        channel[:statuses] = statuses_from_channel_accounts(account_ids)
      end
    end

    def statuses_from_channel_accounts(account_ids)
      Status.where(account_id: account_ids,
                   created_at: (GO_BACK.hours.ago)..Time.current)
    end

    # Returns an array of account id's
    def account_ids(accounts)
      usernames = accounts.pluck(:username)
      domains = accounts.map { |a| a[:domain] == ENV['LOCAL_DOMAIN'] ? nil : a[:domain] }

      Account.where(username: usernames, domain: domains).pluck(:id)
    end

    # HTTP METHODS
    # GET all available channels as a list
    # Channel includes id, title, description, owner
    def list(include_accounts: false)
      cache_key = include_accounts ? 'channels:list:w_accounts' : 'channels:list'
      Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
        response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
          "https://#{ACCOUNT_RELAY_HOST}/api/v1/channels?include_accounts=#{include_accounts}"
        )
        JSON.parse(response.body, symbolize_names: true)
      end
    end

    # GET channel by id and return all details
    def find(id)
      cache_key = "channels:list:#{id}"
      Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
        response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
          "https://#{ACCOUNT_RELAY_HOST}/api/v1/channels/#{id}"
        )
        raise NotFound, 'channel not found' unless response.code == 200

        JSON.parse(response.body, symbolize_names: true)
      end
    end

    # GET all available channel accounts
    # Account username, domain
    def accounts
      response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
        "https://#{ACCOUNT_RELAY_HOST}/api/v1/channels/accounts"
      )
      JSON.parse(response.body, symbolize_names: true)
    end

    # Subscribe to Channel
    def subscribe(id, acct)
      response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).post(
        "https://#{ACCOUNT_RELAY_HOST}/api/v1/channels/#{id}/subscribe?acct=#{acct}"
      )
      raise NotFound, 'channel not found' unless response.code == 200
      PersonalForYou.new.clear_user_cache(acct)

      JSON.parse(response.body, symbolize_names: true)
    end

    # Unsubscribe to Channel
    def unsubscribe(id, acct)
      response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).post(
        "https://#{ACCOUNT_RELAY_HOST}/api/v1/channels/#{id}/unsubscribe?acct=#{acct}"
      )
      raise NotFound, 'channel not found' unless response.code == 200
      PersonalForYou.new.clear_user_cache(acct)

      JSON.parse(response.body, symbolize_names: true)
    end
  end
end
