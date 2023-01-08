# frozen_string_literal: true

require 'http'
require 'json'

class Scheduler::Trends::TrendsUpdateScheduler
  # On small servers especially, the explore tab is not
  # especially useful.  This worker pulls the trending feed
  # from a list of popular servers to improve our own
  include Sidekiq::Worker
  include JsonLdHelper

  SERVERS = %w(
    https://mastodon.social
    https://mstdn.social
    https://ruby.social
    https://hachyderm.io
  ).freeze

  ENDPOINT = '/api/v1/trends/'

  sidekiq_options retry: 0

  def perform
    SERVERS.each do |server|
      begin
        get_statuses("#{server}#{ENDPOINT}statuses")
        get_tags("#{server}#{ENDPOINT}tags")
        get_links("#{server}#{ENDPOINT}links")
      rescue HTTP::ConnectionError
        Rails.logger.warn("Couldn't access #{server}")
      end
    end

    Trends.refresh!
  end

  def get_statuses(url)
    Request.new(:get, url).perform do |response|
      break if response.code != 200
      body = response.body_with_limit
      statuses = body_to_json(body)

      statuses.each do |status|
        new_status = FetchRemoteStatusService.new.call(status['url'], status)
        new_status.status_stat.update(
          replies_count: status['replies_count'],
          favourites_count: status['favourites_count'],
          reblogs_count: status['reblogs_count']
        )

        next unless new_status
        FetchLinkCardService.new.call(new_status)
        Trends::Statuses.new.register(new_status)

        new_status.preview_cards.update_all(trendable: true)
      end
    end
  end

  def get_tags(url)
    Request.new(:get, url).perform do |response|
      break if response.code != 200
      body = response.body_with_limit
      tags = body_to_json(body)

      tags.each do |tag|
        new_tag = Tag.find_or_create_by_names(tag['name'])[0]
        max_score = calculate_max_score(tag['history'])
        new_tag.update(max_score: max_score, max_score_at: Time.now.utc)
      end
    end
  end

  def get_links(url)
    # the way mastodon is architected, links must be associated
    # with a status.  Any links pulled here that aren't already
    # associated with a status won't show up.  This just makes sure
    # they're scored appropriately.
    Request.new(:get, url).perform do |response|
      break if response.code != 200
      body = response.body_with_limit
      links = body_to_json(body)

      links.each do |link|
        card = PreviewCard.find_by(url: link['url'])
        next unless card
        max_score = calculate_max_score(link['history'])
        if max_score >= card.max_score
          card.update(max_score: max_score, max_score_at: Time.now.utc)
        end
      end
    end
  end

  def calculate_max_score(history)
    return 0 if history.length < 2
    expected = history[1]['accounts'].to_f
    observed = history[0]['accounts'].to_f
    ((observed - expected)**2) / expected
  end
end
