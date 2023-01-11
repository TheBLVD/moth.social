# frozen_string_literal: true
require 'rails_helper'

RSpec.describe FollowRecommendations do
  describe '#account_indirect_follows' do # rubocop:disable all
    let(:user_details) { attachment_fixture('user_details.json') }
    let(:following_details) { attachment_fixture('indirect_user_details.json') }
    let(:user_following) { attachment_fixture('user_following.json') }
    let(:indirect_following) { attachment_fixture('indirect_following.json') }
    let(:handle) { 'felipecsl@moth.social' }
    let(:expected_recommendations) do
      JSON.parse(attachment_fixture('expected_follow_recommendations.json').read)
          .map(&:symbolize_keys)
    end
    let!(:stubs) do
      [stub_request(:get, 'https://moth.social/api/v1/accounts/lookup?acct=felipecsl')
        .to_return(body: user_details, status: 200),
       stub_request(:get, 'https://moth.social/api/v1/accounts/09559751135227688/following')
         .to_return(body: user_following, status: 200),
       stub_request(:get, 'https://fiasco.social/api/v1/accounts/lookup?acct=indirect')
         .to_return(body: following_details, status: 200),
       stub_request(:get, 'https://fiasco.social/api/v1/accounts/109281623800601604/following')
         .to_return(body: indirect_following, status: 200)]
    end

    it 'returns follow recommendations' do
      follow_recommendations = described_class.new(handle: handle)
      recommendations = follow_recommendations.account_indirect_follows
      expect(recommendations).to eq(expected_recommendations)
    end

    it 'does returns recommendations from the cache if available' do # rubocop:disable all
      follow_recommendations = described_class.new(handle: handle)
      recommendations = follow_recommendations.account_indirect_follows
      expect(recommendations).to eq(expected_recommendations)
      # remove stubs to ensure we're not making the same requests again
      stubs.each { |stub| remove_request_stub(stub) }
      follow_recommendations = described_class.new(handle: handle)
      recommendations = follow_recommendations.account_indirect_follows
      expect(recommendations).to eq(expected_recommendations)
    end

    it 'deletes cache entry and re-fetches when force: true' do # rubocop:disable all
      follow_recommendations = described_class.new(handle: handle)
      recommendations = follow_recommendations.account_indirect_follows
      expect(recommendations).to eq(expected_recommendations)
      # remove stubs to ensure we're not making the same requests again
      stubs.each { |stub| remove_request_stub(stub) }
      follow_recommendations = described_class.new(handle: handle)
      # this should attempt to make network requests again and fail
      expect do
        follow_recommendations.account_indirect_follows(force: true)
      end.to raise_error(WebMock::NetConnectNotAllowedError)
    end
  end
end
