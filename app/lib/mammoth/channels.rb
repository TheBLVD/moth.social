# frozen_string_literal: true
module Mammoth
  class Channels
    class NotFound < StandardError; end

    ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}"
    ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'

    # GET all available channels as a list
    # Channl includes id, title, description, owner
    def list
      cache_key = 'channels:list'
      Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
        response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
          "https://#{ACCOUNT_RELAY_HOST}/api/v1/channels"
        )
        JSON.parse(response.body, symbolize_names: true)
      end
    end

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
  end
end
