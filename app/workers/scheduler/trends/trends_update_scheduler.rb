# frozen_string_literal: true

require 'http'
require 'json'

class Scheduler::Trends::TrendsUpdateScheduler
  # On small servers especially, the explore tab is not
  # especially useful.  This worker pulls the trending feed
  # from a list of popular servers to improve our own
  include Sidekiq::Worker

  sidekiq_options retry: 0

  def perform # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    servers = [
      'https://mastodon.social',
      'https://mstdn.social',
      'https://ruby.social',
      'https://hachyderm.io',
    ]

    endpoint = '/api/v1/trends/'
    servers.each do |server|
      begin
        response = HTTP.get("#{server}#{endpoint}statuses")
      rescue HTTP::ConnectionError
        Rails.logger.warn("Couldn't access #{server}")
        next
      end

      response = JSON.parse response.to_s

      response.each do |status|
        new_status = FetchRemoteStatusService.new.call(status['url'])
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

      acc = Account.new username: 'admin'
      ActivityPub::FetchFeaturedTagsCollectionService.new.call(acc, "#{server}#{endpoint}tags")

      begin
        tags = JSON.parse(HTTP.get("#{server}#{endpoint}tags").to_s)
      rescue HTTP::ConnectionError
        Rails.logger.warn("couldn't connect to #{server}")
        next
      end

      tags.each do |tag|
        new_tag = Tag.find_or_create_by_names(tag['name'])[0]
        max_score = calculate_max_score(tag['history'])
        new_tag.update(max_score: max_score, max_score_at: Time.now.utc)
      end

      begin
        links = JSON.parse(HTTP.get("#{server}#{endpoint}links").to_s)
      rescue HTTP::ConnectionError
        Rails.logger.warn("couldn't connect to #{server}")
        next
      end

      links.each do |link|
        card = PreviewCard.find_by(url: link['url'])
        next unless card

        max_score = calculate_max_score(link['history'])
        card.update(max_score: max_score, max_score_at: Time.now.utc)
      end
    end
    Trends.refresh!
  end

  def calculate_max_score(history)
    expected = history[1]['accounts'].to_f
    observed = history[0]['accounts'].to_f
    ((observed - expected)**2) / expected
  end
end
