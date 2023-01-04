# frozen_string_literal: true

class Api::V1::Accounts::FollowRecommendationsController < Api::BaseController
  before_action -> { authorize_if_got_token! :read, :'read:accounts' }
  before_action :set_account

  def index
    local_domain = Rails.configuration.x.local_domain
    follow_recs = FollowRecommendations.new(handle: "@#{@account.acct}@#{local_domain}")
    recommendations = follow_recs.account_indirect_follows
    render(
      json: recommendations.take(limit_param(DEFAULT_ACCOUNTS_LIMIT)),
      each_serializer: REST::AccountSerializer
    )
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end
end
