# frozen_string_literal: true

# Interface with the Account Relay Server
# Add accounts per user that it should fetch and relay back to Moth instance
# This requires an auth Token header to make valid http request to Account Relay Server
class AccountRelayService < BaseService
  ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}"
  ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'

  # @param [String] handle - Must be in the format `@username@domain`
  # @param [String] accounts - This is the output list of accounts from the follow recommendation calculation
  # A list of accounts that the user's (handle) following accounts follow. Friends of friends.
  # This is list posted to the Account Relay server.
  # @return void
  def call(handle, accounts)
    @handle = handle
    @accounts = accounts
    cache_key = "account_relay_list:#{@handle}"

    post_to_acct_relay
  end

  private

  def post_to_acct_relay
    response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).post(
      "https://#{ACCOUNT_RELAY_HOST}/api/v1/accounts", json: acct_relay_body
    )
  end

  # Body for POST call to add accounts to the a specific user's (owner) list
  #   {
  #     "owner": "pxl@moth.social",
  #     "accounts": ["cabel@panic.com","gruber@mastodon.social",
  #   }
  def acct_relay_body
    {
      owner: @handle,
    accounts: @accounts,
    }
  end
end
