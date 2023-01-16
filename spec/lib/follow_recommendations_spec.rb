# frozen_string_literal: true
require 'rails_helper'

WEBFINGER_URLS = %w(
  https://kolektiva.social/system/accounts/avatars/109/322/338/908/834/415/original/63f9c075823c4001.jpeg
  https://kolektiva.social/system/accounts/headers/109/322/338/908/834/415/original/c2d94420989abed4.jpeg
  https://kolektiva.social/users/chadloder/outbox
  https://kolektiva.social/users/chadloder/following
  https://kolektiva.social/users/chadloder/followers
  https://kolektiva.social/users/chadloder/collections/featured
  https://kolektiva.social/users/chadloder/collections/tags
  https://opencollective.com/sb-mutual-aid-care-club
  https://newsletter.extremism.io/
).freeze

RSpec.describe FollowRecommendations do
  describe '#account_indirect_follows' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:user_details) { attachment_fixture('user_details.json') }
    let(:following_details) { attachment_fixture('indirect_user_details.json') }
    let(:user_following) { attachment_fixture('user_following.json') }
    let(:indirect_following) { attachment_fixture('indirect_following.json') }
    let(:webfinger_fixture) { attachment_fixture('webfinger_response.json') }
    let(:user_chadloder) { attachment_fixture('user_chadloder.json') }
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
         .to_return(body: indirect_following, status: 200),
       stub_request(:get, 'https://kolektiva.social/.well-known/webfinger?resource=acct:chadloder@kolektiva.social')
         .to_return(body: webfinger_fixture, status: 200),
       stub_request(:get, 'https://kolektiva.social/users/chadloder')
         .to_return(body: user_chadloder, status: 200)] + WEBFINGER_URLS.map do |url|
                                                            stub_request(:get, url).to_return(status: 200, body: '')
                                                          end
    end

    it 'returns follow recommendations' do
      follow_recommendations = described_class.new(handle: handle)
      recommendations = follow_recommendations.account_indirect_follows
      expect(recommendations).to eq(expected_recs)
    end

    it 'does returns recommendations from the cache if available' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
      follow_recommendations = described_class.new(handle: handle)
      recommendations = follow_recommendations.account_indirect_follows
      expect(recommendations).to eq(expected_recs)
      # remove stubs to ensure we're not making the same requests again
      stubs.each { |stub| remove_request_stub(stub) }
      follow_recommendations = described_class.new(handle: handle)
      recommendations = follow_recommendations.account_indirect_follows
      expect(recommendations).to eq(expected_recs)
    end

    it 'deletes cache entry and re-fetches when force: true' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
      follow_recommendations = described_class.new(handle: handle)
      recommendations = follow_recommendations.account_indirect_follows
      expect(recommendations).to eq(expected_recs)
      # remove stubs to ensure we're not making the same requests again
      stubs.each { |stub| remove_request_stub(stub) }
      follow_recommendations = described_class.new(handle: handle)
      # this should attempt to make network requests again and fail
      expect do
        follow_recommendations.account_indirect_follows(force: true)
      end.to raise_error(WebMock::NetConnectNotAllowedError)
    end
  end

  # Set the expected recommendation user ID to whatever auto-generated account ID it has in the DB
  def expected_recs
    expected_recommendations[0][:id] = Account.last.id.to_s
    expected_recommendations
  end
end
