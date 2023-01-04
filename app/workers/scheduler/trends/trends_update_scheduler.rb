# frozen_string_literal: true

require 'http'
require 'json'

class Scheduler::Trends::TrendsUpdateScheduler
  include Sidekiq::Worker

  sidekiq_options retry: 0

  def perform
    servers = [
      'https://mastodon.social',
      'https://mstdn.social',
      'https://ruby.social',
      'https://hachyderm.io',
    ]

    endpoint = '/api/v1/trends/'
    servers.each do |server|
      response = HTTP.get("#{server}#{endpoint}statuses")
      response = JSON.parse response.to_s

      response.each do |status|
        s = FetchRemoteStatusService.new.call(status['url'])
        s.status_stat.update(
          replies_count: status['replies_count'],
          favourites_count: status['favourites_count'],
          reblogs_count: status['reblogs_count']
        )

        next unless s
        FetchLinkCardService.new.call(s)
        Trends::Statuses.new.register s

        s.preview_cards.update_all(trendable: true)
      end

      acc = Account.new username: 'admin'
      ActivityPub::FetchFeaturedTagsCollectionService.new.call(acc, "#{server}#{endpoint}tags")
      tags = JSON.parse(HTTP.get("#{server}#{endpoint}tags").to_s)

      tags.each do |tag|
        t = Tag.find_or_create_by_names(tag['name'])[0]
        max_score = calculate_max_score(tag['history'])
        t.update(max_score: max_score, max_score_at: Time.now.utc)
      end

      links = JSON.parse(HTTP.get("#{server}#{endpoint}links").to_s)
      links.each do |link|
        l = PreviewCard.find_by(url: link['url'])
        next unless l

        max_score = calculate_max_score(link['history'])
        l.update(max_score: max_score, max_score_at: Time.now.utc)
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
