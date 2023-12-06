module Mammoth
  class Users
    class Error < StandardError; end

    ACCOUNT_RELAY_AUTH = "Bearer #{ENV.fetch('ACCOUNT_RELAY_KEY')}".freeze
    ACCOUNT_RELAY_HOST = 'acctrelay.moth.social'.freeze

    def all_mammoth_users
      users
    end

    private

    def users
      current_page = 1
      total_pages = 0
      next_page = "https://#{ACCOUNT_RELAY_HOST}/api/v1/admin/users"
      data = []
      while current_page != total_pages
        response = fetch("https://#{ACCOUNT_RELAY_HOST}/api/v1/admin/users?page=#{current_page}")
        current_page += 1
        total_pages = response['Total-Pages']
        Rails.logger.debug { "HTTP RESPONSE: #{response.inspect}" }
        Rails.logger.debug { "HTTP CURRENT PAGE: #{response['Current-Page']}" }
        Rails.logger.debug { "HTTP TOTAL PAGES: #{response['Total-Pages']}" }
        raise Users::Error, "Request for users returned HTTP #{response.code}" unless response.code == 200

        page = JSON.parse(response.body).map(&:symbolize_keys).pluck(:acct)
        # Rails.logger.debug { "PAGE_DATE: #{page}" }
        data += page
      end
      data
    rescue => e
      raise Users::Error, 'Unable to parse mammoth users from AcctRelay', e
    end

    def get_next_page(link_header)
      return nil unless link_header

      # Example header:
      # Link: <https://acctrelay.moth.social/api/v1/admin/users?page=1>; rel="first", <https://acctrelay.moth.social/api/v1/admin/users?page=2>; rel="next", <https://acctrelay.moth.social/api/v1/admin/users?page=6>; rel="last"
      match = link_header.scan(/<([^>]+)/)
      Rails.logger.debug { "LINK HEADER >> \n #{link_header}" }
      Rails.logger.debug { "MATCH >> \n #{match}" }
      match[1][0]
    end

    def fetch(url)
      HTTP.headers({ Authorization: ACCOUNT_RELAY_AUTH, 'Content-Type': 'application/json' }).get(url)
    end
  end
end
