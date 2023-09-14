# frozen_string_literal: true

class PersonalForYou
  include Redisable
  include Async

  ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}"
  ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'

  # Cache Key for User
  def key(acct)
    "mammoth:user:#{acct}"
  end

  # Indirect Follows are the following of your followers
  # Get full account handle <example@moth.social>
  # IE Friends of Friends
  def statuses_for_indirect_follows(account_handle)
    cache_key = "follow_recommendations:#{account_handle}"
    fedi_account_handles = Rails.cache.fetch(cache_key)
    Rails.logger.debug { "INDIRECT FOLLOW RECOMMENDATIONS HANDLES\n #{fedi_account_handles}" }
    # Early return if no fedi account handles found
    return [] if fedi_account_handles.nil?
    # Parse handles into username & domain array for batch account query
    username_query = []
    domain_query = []
    fedi_account_handles.each do |handle|
      h = handle.split('@')
      username_query.push(h[0])
      domain_query.push(h[1])
    end
    # Array of account id's from fedi_account_handles
    account_ids = Account.where(username: username_query, domain: domain_query).pluck(:id)
    Rails.logger.debug { "INDIRECT FOLLOW RECOMMENDATIONS USERNAMES\n #{username_query}" }
    Rails.logger.debug { "INDIRECT FOLLOW RECOMMENDATIONS ACCOUNT_IDS\n #{account_ids}" }
    # Get Statuses for those accounts
    Status.where(account_id: account_ids, updated_at: 12.hours.ago..Time.current).limit(200)
  end

  # Get All registered users from AcctRely
  # `api/v1/foryou/users`
  # That are  personalize:true, meaning they are Mammoth Users
  def acct_relay_users
    response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
      "https://#{ACCOUNT_RELAY_HOST}/api/v1/foryou/users"
    )
    results = JSON.parse(response.body).map(&:symbolize_keys).pluck(:acct)
    results unless response.code != 200
  end

  # Get Mammoth user details
  # Includes any settings/preferences/configurations for feeds
  # Not caching user. If it becomes an issue cache it at the source. AcctRelay
  def user(acct)
    response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
      "https://#{ACCOUNT_RELAY_HOST}/api/v1/foryou/users/#{acct}"
    )
    JSON.parse(response.body, symbolize_names: true)
  end

  # Defined as a 'personalize' user on AccountRelay
  # A Mammoth user will have thier foryou settings type listed as 'personal' once it's generated
  # The default foryou settings type is 'public
  def personalized_mammoth_user?(acct)
    user(acct).dig(:for_you_settings, :type) == 'personal'
  end

  # PUT Mammoth user for you settings / preferences / status
  # Bust User cache when updating user settings
  def update_user(acct, payload)
    response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).put(
      "https://#{ACCOUNT_RELAY_HOST}/api/v1/foryou/users/#{acct}", json: payload
    )
    clear_user_cache(acct)
    JSON.parse(response.body)
  end

  # Cache bust local user
  def clear_user_cache(acct)
    Rails.cache.delete(key(acct))
  end

  # Get Mammoth user following
  def user_following(acct)
    response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
      "https://#{ACCOUNT_RELAY_HOST}/api/v1/foryou/users/#{acct}/following"
    )
    # Get Following
    results = JSON.parse(response.body)['following']
    results unless response.code != 200
  end

  def statuses_for_direct_follows(acct)
    following = user_following(acct)
    Rails.logger.debug { "FOLLOW RECOMMENDATIONS RETURN \n #{following}" }
    # Parse handles into username & domain array for batch account query
    username_query = []
    domain_query = []
    following.each do |user|
      # Local accounts will have a domain of nil
      domain = user['domain'] == ENV['LOCAL_DOMAIN'] ? nil : user['domain']
      username_query.push(user['username'])
      domain_query.push(domain)
    end
    Rails.logger.debug { "FOLLOW RECOMMENDATIONS USERNAMES \n #{username_query}" }
    # Array of account id's from fedi_account_handles
    account_ids = Account.where(username: username_query, domain: domain_query).pluck(:id)
    # Get Statuses for those accounts
    Status.where(account_id: account_ids, updated_at: 12.hours.ago..Time.current).limit(200)
  end

  # Get subscribed channels with full accounts
  # Fetch statuses for those accounts
  def statuses_for_subscribed_channels(user)
    channels = Mammoth::Channels.new
    subscribed_channels = subscribed_channels(user)
    channels.select_channels_with_statuses(subscribed_channels)
  end

  # Only include channels from user subscribed
  # Return 'mammoth channels' that has the full accounts array
  # User's subscribed array only has channel summary
  def subscribed_channels(user)
    channels = mammoth_channels.wait
    subscribed_channels = user[:subscribed_channels]

    subscribed_channels.wait.flat_map do |channel|
      channels.filter do |c|
        c[:id] == channel[:id]
      end
    end
  end

  def mammoth_channels
    channels = Mammoth::Channels.new
    Async do
      channels.list(include_accounts: true)
    end
  end

  # Remove personal timeline this will remove all entries in user's personal for you feed
  # Current behavior is to default to 'public' mammoth curated feed if user's personal feed is blank 8/16/2023
  def reset_feed(account_id)
    Rails.logger.debug { "RESETTING THE FEED>>>>>>>>>> \n #{account_id} \n" }
    timeline_key = FeedManager.instance.key('personal', account_id)
    redis.del(timeline_key)
  end
end
