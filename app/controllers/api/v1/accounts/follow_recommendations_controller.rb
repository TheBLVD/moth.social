# frozen_string_literal: true

class Api::V1::Accounts::FollowRecommendationsController < Api::BaseController
  before_action -> { authorize_if_got_token! :read, :'read:accounts' }
  before_action :set_account

  def index
    handle = @account.local_username_and_domain
    service = FollowRecommendationsService.new
    recommendation_handles = service.call(handle: handle)
    recommendations = recommendation_handles
                      .filter_map { |handle| handle_to_account(handle) }
                      .take(limit_param(DEFAULT_ACCOUNTS_LIMIT))
    render json: recommendations, each_serializer: REST::AccountSerializer
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def handle_to_account(handle)
    username, domain = handle.strip.gsub(/\A@/, '').split('@')
    Account.find_remote(username, domain)
  end
end
