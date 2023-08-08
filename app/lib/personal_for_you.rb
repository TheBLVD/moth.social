# frozen_string_literal: true

class PersonalForYou
  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  BETA_FOR_YOU_LIST = 'Beta ForYou Personalized'
  ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}"
  ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'

  def beta_list_accounts
    default_owner_account = Account.local.where(username: FOR_YOU_OWNER_ACCOUNT).first!
    beta_list = List.where(account: default_owner_account, title: BETA_FOR_YOU_LIST).first!
    beta_list.accounts.without_suspended.includes(:account_stat)
  end

  # Indirect Follows are the following of your followers
  # IE Friends of Friends
  def statuses_for_indirect_follows(account)
    # Get full account handle <example@moth.social>
    account_handle = account.local? ? account.local_username_and_domain : account.acct
    cache_key = "follow_recommendations:#{account_handle}"
    fedi_account_handles = Rails.cache.fetch(cache_key)
    # Parse handles into username & domain array for batch account query
    username_query = Array.[]
    domain_query = Array.[]
    fedi_account_handles.each do |handle|
      h = handle.split('@')
      username_query.push(h[0])
      domain_query.push(h[1])
    end
    # Array of account id's from fedi_account_handles
    account_ids = Account.where(username: username_query, domain: domain_query).pluck(:id)
    # Get Statuses for those accounts
    Status.where(account_id: account_ids, updated_at: 12.hours.ago..Time.now).limit(200)
  end

  # Get All registered users from AcctRely
  # `api/v1/foryou/users`
  # That are local:true, meaning they are Mammoth Users
  def acct_relay_users
    response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
      "https://#{ACCOUNT_RELAY_HOST}/api/v1/foryou/users"
    )
    results = JSON.parse(response.body).map(&:symbolize_keys).pluck(:acct)
    return results unless response.code != 200
  end

  # Get Mammoth user details
  # Includes any settings/preferences/configurations for feeds
  def user(acct)
    response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
      "https://#{ACCOUNT_RELAY_HOST}/api/v1/foryou/users/#{acct}"
    )
    results = JSON.parse(response.body)
    return results unless response.code != 200
  end

  # Get Mammoth user following
  def user_following(acct)
    response = HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(
      "https://#{ACCOUNT_RELAY_HOST}/api/v1/foryou/users/#{acct}/following"
    )
    # Get Following
    results = JSON.parse(response.body)['following']
    return results unless response.code != 200
  end

  def statuses_for_direct_follows(acct)
    following = user_following(acct)
    # Parse handles into username & domain array for batch account query
    username_query = Array.[]
    domain_query = Array.[]
    following.each do |user|
      username_query.push(user['username'])
      domain_query.push(user['domain'])
    end
    # Array of account id's from fedi_account_handles
    account_ids = Account.where(username: username_query, domain: domain_query).pluck(:id)
    # Get Statuses for those accounts
    Status.where(account_id: account_ids, updated_at: 12.hours.ago..Time.now).limit(200)
  end
end
