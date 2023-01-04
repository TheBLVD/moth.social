# frozen_string_literal: true
class FollowRecommendations
  def initialize(handle:, limit: 200)
    @handle = handle
    @limit = limit
  end

  # Returns an array of account follow recommendations for the provided handle
  # This is basically a ruby port of https://followgraph.vercel.app/
  # Returns an array of hashes sorted by most followed accounts first
  # (eg.: N of the people you follow also follow this account).
  # See the method `account_follows` below for the hash format
  def account_indirect_follows # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    direct_follows = account_follows(@handle).map(&:symbolize_keys)
    direct_follow_ids = Set.new(direct_follows.pluck(:acct))
    direct_follow_ids.add(@handle.sub(/^@/, ''))
    indirect_follow_map = {}
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
      .filter { |ind_follow| direct_follow_ids.exclude?(ind_follow[:acct]) && ind_follow[:discoverable] }
      .each do |account|
        indirect_acct = account[:acct]
        if indirect_follow_map.key?(indirect_acct)
          other_account = indirect_follow_map[indirect_acct]
          account[:followed_by].merge(other_account[:followed_by].to_a)
        end
        indirect_follow_map[indirect_acct] = account
      end
    indirect_follow_map.values.uniq { |v| v[:username] }.sort do |a, b|
      if a[:followed_by].size == b[:followed_by].size
        b[:followers_count] - a[:followers_count]
      else
        b[:followed_by].size - a[:followed_by].size
      end
    end
  end

  private

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
    next_page = "https://#{domain}/api/v1/accounts/#{id}/following"
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
    http.use_ssl = true
    request = Net::HTTP::Get.new(url)
    http.request(request)
  end

  # Returns the user ID and domain for the provided handle, eg `@felipecsl@moth.social`
  def username_to_id(handle)
    match = handle.match(/^(.+)@(.+)$/)
    if !match || match.length < 2
      raise StandardError, "Incorrect handle: #{handle}"
    end
    domain = match[2]
    username = match[1]
    response = fetch("https://#{domain}/api/v1/accounts/lookup?acct=#{username}")
    if response.code.to_i != 200
      raise StandardError, 'HTTP request failed'
    end
    id = JSON.parse(response.body).symbolize_keys[:id]
    [id, domain]
  end
end
