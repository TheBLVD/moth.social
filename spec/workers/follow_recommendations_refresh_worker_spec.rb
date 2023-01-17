# frozen_string_literal: true

require 'rails_helper'

describe FollowRecommendationsRefreshWorker do
  subject { described_class.new }

  let(:handle) { 'alice' }
  let(:limit) { 10 }

  describe 'perform' do
    it 'call FollowRecommendationsService and ResolveAccountWorker' do # rubocop:disable all
      allow_any_instance_of(FollowRecommendationsService).to receive(:call)
        .with(handle: handle, limit: limit, force: true)
        .and_return(%w(john@foo.bar doe@baz.qux))
      expect(ResolveAccountWorker).to receive(:perform_async).with('john@foo.bar')
      expect(ResolveAccountWorker).to receive(:perform_async).with('doe@baz.qux')
      subject.perform(handle, limit)
    end
  end
end
