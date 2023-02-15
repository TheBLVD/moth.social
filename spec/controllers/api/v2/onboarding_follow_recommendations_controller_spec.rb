# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V2::OnboardingFollowRecommendationsController do
  let!(:accounts) do
    %w(foo@bar.baz roberto@gomez.bolanos elchavo@del.ocho carlos@villa.gran)
      .map { |a| a.split('@') }
      .map { |a| Fabricate(:account, domain: a[1], username: a[0], url: 'https://example.com/') }
  end

  it 'returns http success with onboarding categories json' do
    default_props = {
      display_name: '',
      locked: false,
      bot: false,
      discoverable: true,
      group: false,
      note: '',
      url: 'https://example.com/',
      avatar: 'https://cb6e6126.ngrok.io/avatars/original/missing.png',
      avatar_static: 'https://cb6e6126.ngrok.io/avatars/original/missing.png',
      header: 'https://cb6e6126.ngrok.io/headers/original/missing.png',
      header_static: 'https://cb6e6126.ngrok.io/headers/original/missing.png',
      followers_count: 0,
      following_count: 0,
      statuses_count: 0,
      last_status_at: nil,
      emojis: [],
      fields: [],
    }
    get :index
    expect(response).to have_http_status(:ok)
    expected_body = [
      {
        name: 'Tech',
        items: [
          {
            id: accounts[0].id.to_s,
            created_at: accounts[0].created_at.midnight.as_json,
            username: 'foo',
            type: 'account',
            acct: 'foo@bar.baz',
            **default_props,
            summary: 'asdf1',
          },
          {
            id: accounts[1].id.to_s,
            type: 'account',
            username: 'roberto',
            acct: 'roberto@gomez.bolanos',
            created_at: accounts[1].created_at.midnight.as_json,
            **default_props,
            summary: 'asdf2',
          },
          {
            hashtag: '#rubyonrails',
            type: 'hashtag',
            summary: 'mastodon runs on rails!',
            bio: 'sinatra is better tho',
          },
        ],
      },
      {
        name: 'News & Journalists',
        items: [
          {
            id: accounts[2].id.to_s,
            username: 'elchavo',
            acct: 'elchavo@del.ocho',
            type: 'account',
            created_at: accounts[2].created_at.midnight.as_json,
            **default_props,
            summary: 'asdf3',
          },
          {
            id: accounts[3].id.to_s,
            username: 'carlos',
            type: 'account',
            acct: 'carlos@villa.gran',
            created_at: accounts[3].created_at.midnight.as_json,
            **default_props,
            summary: 'asdf4',
          },
        ],
      },
    ]
    expect(body_as_json).to eq(expected_body)
  end
end
