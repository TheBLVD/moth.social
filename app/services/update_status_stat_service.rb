# frozen_string_literal: true

class UpdateStatusStatService < BaseService
  include Redisable
  include JsonLdHelper
  include LanguagesHelper

  ENDPOINT = '/api/v1/statuses/'

  class NoChangesSubmittedError < StandardError; end

  # @param [Status] status
  # @param [Hash] options
  def call(status, _options = {})
    # Fetch status from source
    host = URI.parse(status['uri']).host
    status_id = status['uri'].split('/').last
    get_status("https://#{host}#{ENDPOINT}#{status_id}", status['id'])
  end

  def get_status(url, id)
    Request.new(:get, url).perform do |response|
      break if response.code != 200
      body = response.body_with_limit
      status = body_to_json(body)

      updated_status = Status.find(id)

      updated_status.status_stat.update(
        replies_count: status['replies_count'],
        favourites_count: status['favourites_count'],
        reblogs_count: status['reblogs_count']
      )
    end
  end
end
