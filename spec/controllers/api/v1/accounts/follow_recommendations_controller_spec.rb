# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Accounts::FollowRecommendationsController do
  render_views

  let(:account) { Fabricate(:account) }
  let!(:followed_account) { Fabricate(:account, domain: 'moth.social', username: 'alice', url: 'https://example.com/') }
  let!(:remote_account) { Fabricate(:account, domain: 'bar.baz', username: 'foo', url: 'https://remote.test/') }
  let(:scopes) { 'read' }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: account.user.id, scopes: scopes) }

  before do
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  describe 'GET #index' do
    it 'returns http success with follow recommendations' do
      allow_any_instance_of(FollowRecommendationsService).to receive(:call).and_return(['foo@bar.baz'])
      get :index, params: { account_id: account.id }

      serializer = REST::AccountSerializer.new(remote_account)
      expect(response).to have_http_status(:ok)
      expect(body_as_json).to eq([JSON.parse(serializer.to_json, symbolize_names: true)])
    end

    it 'excludes from recommendations response accounts that already being followed' do
      account.follow!(followed_account)
      allow_any_instance_of(FollowRecommendationsService).to receive(:call).and_return(%w(foo@bar.baz alice@moth.social))
      get :index, params: { account_id: account.id }

      serializer = REST::AccountSerializer.new(remote_account)
      expect(response).to have_http_status(:ok)
      expect(body_as_json).to eq([JSON.parse(serializer.to_json, symbolize_names: true)])
    end
  end
end
