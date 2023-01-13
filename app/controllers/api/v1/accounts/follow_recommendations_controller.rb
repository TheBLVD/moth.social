# frozen_string_literal: true

class Api::V1::Accounts::FollowRecommendationsController < Api::BaseController
  before_action -> { authorize_if_got_token! :read, :'read:accounts' }
  before_action :set_account

  def index
    handle = @account.local_username_and_domain
    follow_recs = FollowRecommendations.new(handle: handle)
    recommendations = follow_recs.account_indirect_follows
    render json: recommendations.take(limit_param(DEFAULT_ACCOUNTS_LIMIT))
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end
end