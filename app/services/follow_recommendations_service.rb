# frozen_string_literal: true

# Returns an array of string user handles (eg: johndoe@mastodon.server) with follow recommendations
# for the provided user, according to other users that are the most followed by their existing follows.
class FollowRecommendationsService < BaseService
  # We're making the assumption that these 3 accounts below exist in the local server and they
  # represent the moth.social staff. Please keep this list up to date!
  MAX_RESULTS = 50
  DEFAULT_FOLLOW_LIMIT = 200

  # @param [String] handle - Must be in the format `@username@domain`
  # @param [Integer] limit - This limit affects how many direct follows we'll traverse to find indirect
  #   follows. The higher the limit, the more follow suggestions we may find.
  #   Setting a low limit will make the process faster, but we may miss some indirect follows.
  #   Additionally, in that scenario, we may suggest the user to follow someone they already follow.
  # @param [Boolean] force - If `true`, this will invalidate the cache and force a reload
  # @return a string array of account follow handles recommendations for the provided handle, sorted
  #    by most followed accounts first (eg.: N of the people you follow also follow this account).
  # This is basically a Ruby port of https://followgraph.vercel.app/
  def call(handle:, limit: DEFAULT_FOLLOW_LIMIT, force: false)
    @handle = handle
    @limit = limit
    cache_key = "follow_recommendations:#{@handle}"
    Rails.cache.fetch(cache_key, expires_in: 6.months, force: force) do
      direct_follows = account_follows(@handle).map(&:symbolize_keys)
      if direct_follows.empty?
        Rails.logger.info("No follows found for #{@handle}, defaulting to `SUGGESTIONS API V2`")
        generate_default_follows.map(&:symbolize_keys)
      end
      direct_follow_ids = Set.new(direct_follows.pluck(:acct))
      direct_follow_ids.add(@handle.sub(/^@/, ''))
      indirect_follows = populate_indirect_follows(direct_follows)
      indirect_follow_map = build_follow_graph(indirect_follows, direct_follow_ids).values
      indirect_follow_map
        .uniq { |v| v[:username] }
        .take(DEFAULT_FOLLOW_LIMIT)
        .sort { |a, b| sort_order(a, b) }
        .pluck(:acct)
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

  # Returns an array of default follows from V2 Suggestions API
  def generate_default_follows
    account = account_from_handle
    AccountSuggestions.get(account, MAX_RESULTS).map { |suggest| suggest.account.acct }
  end

  def account_from_handle
    username, domain = @handle.split('@')
    domain = nil if domain == Rails.configuration.x.local_domain
    Account.where(username: username, domain: domain).first
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
  rescue => e
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
    raise StandardError, 'HTTP request failed' if response.code.to_i != 200

    id = JSON.parse(response.body).symbolize_keys[:id]
    [id, domain]
  end

  def username_and_domain(handle)
    match = handle.match(/^(.+)@(.+)$/)
    raise StandardError, "Incorrect handle: #{handle}" if !match || match.length < 2

    domain = match[2]
    username = match[1]
    [username, domain]
  end
end
