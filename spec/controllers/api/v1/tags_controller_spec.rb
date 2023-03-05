# frozen_string_literal: true

require 'rails_helper'
# rubocop:disable all
RSpec.describe Api::V1::TagsController, type: :controller do
  render_views

  let(:user)   { Fabricate(:user) }
  let(:scopes) { 'write:follows' }
  let(:token)  { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }

  before { allow(controller).to receive(:doorkeeper_token) { token } }

  describe 'GET #show' do
    before do
      get :show, params: { id: name }
    end

    context 'with existing tag' do
      let!(:tag) { Fabricate(:tag) }
      let(:name) { tag.name }

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end
    end

    context 'with non-existing tag' do
      let(:name) { 'hoge' }

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST #follow' do
    let!(:unrelated_tag) { Fabricate(:tag) }
    let!(:params) { {id: name} }

    before do
      allow(RegenerationWorker).to receive(:perform_async)
      TagFollow.create!(account: user.account, tag: unrelated_tag)

      post :follow, params: params
    end

    context 'with existing tag' do
      let!(:tag) { Fabricate(:tag) }
      let(:name) { tag.name }

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'creates follow' do
        expect(TagFollow.where(tag: tag, account: user.account).exists?).to be true
      end

    end

    context 'with a rebuild param' do
      let!(:params) { super().merge(rebuild: true) }
      let!(:tag) { Fabricate(:tag) }
      let(:name) { tag.name }

      it 'rebuilds if necessary' do
        expect(RegenerationWorker).to have_received(:perform_async)
      end
    end

    context 'with non-existing tag' do
      let(:name) { 'hoge' }

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'creates follow' do
        expect(TagFollow.where(tag: Tag.find_by!(name: name), account: user.account).exists?).to be true
      end
    end
  end

  describe 'POST #unfollow' do
    let!(:tag) { Fabricate(:tag, name: 'foo') }
    let!(:tag_follow) { Fabricate(:tag_follow, account: user.account, tag: tag) }
    let!(:params) { { id: tag.name } }

    before do
      allow(RegenerationWorker).to receive(:perform_async)
      post :unfollow, params: params
    end

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'removes the follow' do
      expect(TagFollow.where(tag: tag, account: user.account).exists?).to be false
    end

    context 'with a rebuild param' do
      let!(:params) { super().merge(rebuild: true) }

      it 'rebuilds if necessary' do
        expect(RegenerationWorker).to have_received(:perform_async)
      end
    end

  end
end

# rubocop:enable all
