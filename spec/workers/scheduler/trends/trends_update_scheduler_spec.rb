# frozen_string_literal: true

require 'rails_helper'

describe Scheduler::Trends::TrendsUpdateScheduler do
  subject { described_class.new }

  let!(:account) { Fabricate(:account, domain: 'example.com', uri: 'https://example.com/foo') }

  describe '#get_statuses' do
    before do
      stub_request(:get, url).to_return(status: 200,
                                        body: statuses.to_json,
                                        headers: {})
      statuses.each do |status|
        stub_request(:get, status[:uri]).to_return(status: 200,
                                                    body: status.to_json,
                                                    headers: {})
      end
    end

    context 'when simple status' do
      let(:statuses) do
        1.upto(20).map do |i|
          {
            '@context': 'https://www.w3.org/ns/activitystreams',
            id: "https://example.com/@foo/#{i}",
            url: "https://example.com/@foo/#{i}",
            uri: "https://example.com/@foo/#{i}",
            type: 'Note',
            content: 'Lorem ipsum',
            attributedTo: ActivityPub::TagManager.instance.uri_for(account),
            replies_count: 1,
            favourites_count: 1,
            reblogs_count: 1,
          }
        end
      end
      let(:url) { 'https://example.com/api/v1/trends/statuses' }

      it 'creates the statuses' do
        expect { subject.get_statuses(url) }.to change(Status, :count).by(20)
      end
    end
  end

  describe '#calculate_max_score' do
    context 'when history is too short' do
      let(:history) { [] }

      it 'returns 0' do
        expect(subject.calculate_max_score(history)).to eq(0)
      end
    end

    context 'when history exists' do
      let(:history) { [{ 'accounts' => 4 }, { 'accounts' => 5 }] }

      it 'calculates the max score' do
        expect(subject.calculate_max_score(history)).to eq(0.2)
      end
    end
  end
end
