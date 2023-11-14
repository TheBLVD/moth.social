# frozen_string_literal: true

module Mammoth
  class Channels
    class NotFound < StandardError; end

    GO_BACK = 24 # number of hours back to fetch statuses
    ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}".freeze
    ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'

    # Get all channels
    # Get accounts for each channel
    # process: filter by engagment and add cache set with channel_id key
    def channels_with_statuses
      list(include_accounts: true).each do |channel|
        account_ids = account_ids(channel[:accounts])
        channel[:statuses] = statuses_from_channels(account_ids)
      end
    end

    # Used in ForYou Feed
    # Get Statuses from array of channels
    # filter out based on per channel threshold
    # User is passed all the way down to be able
    # to add specific origin per user, per channel for a status.
    def select_channels_with_statuses(channels, user)
      origin = Mammoth::StatusOrigin.instance
      channels.flat_map do |channel|
        account_ids = account_ids(channel[:accounts])
        statuses_with_accounts_from_channels(account_ids).filter_map { |s| engagment_threshold(s, channel[:fy_engagement_threshold]) }
                                                         .each { |s| origin.add_channel(s, user, channel) }
      end
    end

    # Return statuses for each channel that meets it's respective engagement threshold
    # Ensure we are checking statues as far back at 48 hours
    def filter_statuses_with_threshold
      channels_with_statuses.map do |channel|
        channel[:statuses] = channel[:statuses].filter_map { |s| engagment_threshold(s, channel[:fy_engagement_threshold]) }
        channel
      end
    end

    def statuses_from_channels(account_ids)
      Status.where(account_id: account_ids,
                   created_at: (GO_BACK.hours.ago)..Time.current)
    end

    # Not entirely sure why we're including `:account`
    def statuses_with_accounts_from_channels(account_ids)
      Status.includes([:account]).where(account_id: account_ids,
                                        created_at: (GO_BACK.hours.ago)..Time.current)
    end

    # Check status for Channel's set level of engagment
    # Filter out polls and replys
    def engagment_threshold(wrapped_status, channel_engagment_setting)
      status = wrapped_status.reblog? ? wrapped_status.reblog : wrapped_status

      status_counts = status.reblogs_count + status.replies_count + status.favourites_count
      status if status_counts >= channel_engagment_setting && status.in_reply_to_id.nil? && status.poll_id.nil?
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
