# frozen_string_literal: true
class FollowRecommendations
  # We're making the assumption that these 3 accounts below exist in the local server and they
  # represent the moth.social staff. Please keep this list up to date!
  DEFAULT_FOLLOW_LIST = %w(mark bart misspurple).freeze
  DEFAULT_FOLLOW_LIMIT = 200

  # @param [String] handle - Must be in the format `@username@domain`
  # @param [Integer] limit - This limit affects how many direct follows we'll traverse to find indirect
  #   follows. The higher the limit, the more follow suggestions we may find.
  #   Setting a low limit will make the process faster, but we may miss some indirect follows.
  #   Additionally, in that scenario, we may suggest the user to follow someone they already follow.
  def initialize(handle:, limit: DEFAULT_FOLLOW_LIMIT)
    @handle = handle
    @limit = limit
  end

  # Returns an array of account follow recommendations for the provided handle
  # This is basically a ruby port of https://followgraph.vercel.app/
  # Returns an array of hashes sorted by most followed accounts first
  # (eg.: N of the people you follow also follow this account).
  # See the method `account_follows` below for the hash format
  # If `force` is `true`, this will invalidate the cache and force a reload
  def account_indirect_follows(force: false)
    Rails.cache.fetch(cache_key, expires_in: 1.week, force: force) do
      direct_follows = account_follows(@handle).map(&:symbolize_keys)
      if direct_follows.empty?
        Rails.logger.info("No follows found for #{@handle}, defaulting to `DEFAULT_FOLLOW_LIST`")
        direct_follows = generate_default_follows.map(&:symbolize_keys)
      end
      direct_follow_ids = Set.new(direct_follows.pluck(:acct))
      direct_follow_ids.add(@handle.sub(/^@/, ''))
      indirect_follows = populate_indirect_follows(direct_follows)
      indirect_follow_map = build_follow_graph(indirect_follows, direct_follow_ids).values
      sorted_follows = indirect_follow_map
                       .uniq { |v| v[:username] }
                       .take(DEFAULT_FOLLOW_LIMIT)
                       .sort { |a, b| sort_order(a, b) }
                       .map { |follow| follow.tap { |f| f[:followed_by] = f[:followed_by].to_a } }
      filter_existing_follows(sorted_follows)
    end
  end

  private

  def sort_order(account_a, account_b)
    if account_a[:followed_by].size == account_b[:followed_by].size
      account_b[:followers_count] - account_a[:followers_count]
    else
      account_b[:followed_by].size - account_a[:followed_by].size
    end
  end

  # Filters the provided list of follow recommendations, removing any follows that the user already follows
  def filter_existing_follows(sorted_follows)
    username, domain = username_and_domain(@handle)
    account = Account.find_by(username: username, domain: domain)
    if account
      follows = Follow.where(account: account).map { |f| f.target_account.acct }
      sorted_follows.reject { |follow| follows.include?(follow[:acct]) }
    else
      sorted_follows
    end
  end

  def cache_key
    "follow_recommendations:#{@handle}"
  end

  def populate_indirect_follows(direct_follows)
    indirect_follows = []
    threads = direct_follows.pluck(:acct).map do |direct_follow|
      Thread.new do
        indirect_follows.concat(
          account_follows(direct_follow).map do |account|
            account[:followed_by] = Set.new([direct_follow])
            account
          end
        )
      end
    end
    threads.each(&:join)
    indirect_follows
  end

  # Returns a map of account username to account details, populating its `followed_by` field according
  # to the set of all users that directly or indirectly follow each user in the map
  def build_follow_graph(indirect_follows, direct_follow_ids)
    indirect_follow_map = {}
    indirect_follows
      .filter { |ind_follow| direct_follow_ids.exclude?(ind_follow[:acct]) && ind_follow[:discoverable] }
      .each do |account|
        indirect_acct = account[:acct]
        if indirect_follow_map.key?(indirect_acct)
          other_account = indirect_follow_map[indirect_acct]
          account[:followed_by].merge(other_account[:followed_by].to_a)
        end
        indirect_follow_map[indirect_acct] = account
      end
    indirect_follow_map
  end

  # Returns an array of default follows in the same JSON format as the public API using AccountSerializer
  def generate_default_follows
    # domain: nil makes sure we're looking for local accounts
    accounts = Account.where(username: DEFAULT_FOLLOW_LIST, domain: nil)
    serializer = ActiveModel::Serializer::CollectionSerializer.new(
      accounts, serializer: REST::AccountSerializer
    )
    JSON.parse(serializer.to_json)
  end

  # returns an array of hashes containing all the accounts details followed by `@handle`:
  # type AccountDetails = {
  #   id: string
  #   username: string
  #   acct: string
  #   followed_by: Set<string> // list of handles
  #   following_count: number
  #   followers_count: number
  #   discoverable: boolean
  #   display_name: string
  #   note: string
  #   locked: boolean
  #   bot: boolean
  #   group: boolean
  #   discoverable: boolean
  #   avatar_static: string
  #   header: string
  #   header_static: string
  # }
  def account_follows(handle)
    id, domain = username_to_id(handle)
    scheme = domain.include?('localhost') ? 'http' : 'https'
    next_page = "#{scheme}://#{domain}/api/v1/accounts/#{id}/following"
    data = []
    while next_page && data.length <= @limit
      response = fetch(next_page)
      if response.code.to_i != 200
        Rails.logger.error("Error while retrieving followers for #{handle}.")
        break
      end
      page = JSON.parse(response.body).map(&:symbolize_keys).map do |entry|
        entry[:acct] += "@#{domain}" unless entry[:acct].include?('@')
        entry
      end
      data += page
      next_page = get_next_page(response['Link'])
    end
    data
  rescue StandardError => e
    Rails.logger.error("Cannot find handle #{handle}: #{e}")
    []
  end

  def get_next_page(link_header)
    return nil unless link_header
    # Example header:
    # Link: <https://mastodon.example/api/v1/accounts/1/follows?limit=2&max_id=7628164>; rel="next", <https://mastodon.example/api/v1/accounts/1/follows?limit=2&since_id=7628165>; rel="prev"
    match = link_header.match(/<(.+)>; rel="next"/)
    match && match[1]
  end

  def fetch(url)
    url = URI(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true if url.scheme == 'https'
    request = Net::HTTP::Get.new(url)
    http.request(request)
  end

  # Returns the user ID and domain for the provided handle, eg `@felipecsl@moth.social`
  def username_to_id(handle)
    username, domain = username_and_domain(handle)
    scheme = domain.include?('localhost') ? 'http' : 'https'
    response = fetch("#{scheme}://#{domain}/api/v1/accounts/lookup?acct=#{username}")
    if response.code.to_i != 200
      raise StandardError, 'HTTP request failed'
    end
    id = JSON.parse(response.body).symbolize_keys[:id]
    [id, domain]
  end

  def username_and_domain(handle)
    match = handle.match(/^(.+)@(.+)$/)
    if !match || match.length < 2
      raise StandardError, "Incorrect handle: #{handle}"
    end
    domain = match[2]
    username = match[1]
    [username, domain]
  end
end
