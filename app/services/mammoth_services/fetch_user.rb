# frozen_string_literal: true
module MammothServices
  # Interface with the Account Relay Server
  # Fetch User w/ details
  # This requires an auth Token header to make valid http request to Account Relay Server
  class FetchUser < BaseService
    ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}"
    ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'

    # @param [String] handle - Must be in the format `@username@domain`
    # A list of accounts that the user's (handle) following accounts follow. Friends of friends.
    # This is list posted to the Account Relay server.
    # @return void
    def call(handle, options = {})
      @handle = handle
      @options = options
      user_from_acct_relay
    end

    private

    def user_from_acct_relay
      response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
        "https://#{ACCOUNT_RELAY_HOST}/api/v1/foryou/users/#{@handle}"
      )
      response.body.to_s
    end
  end
end
