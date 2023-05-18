# frozen_string_literal: true

class Api::V2::FollowRecommendationsGraphController < Api::BaseController
  RECOMMENDED_ACCOUNTS_LIMIT = 80

  before_action -> { authorize_if_got_token! :read, :'read:accounts' }
  before_action :set_account

  def show
    handle = @account.local_username_and_domain
    service = FollowRecommendationsService.new
    recommendation_handles = service.call(handle: handle)
    follows = Follow.where(account: @account).map { |f| f.target_account.acct }
    recommendations = recommendation_handles
                      .reject { |recommendation| follows.include?(recommendation) }
                      .filter_map { |h| handle_to_account_remote(h) }
                      .take(limit_param(RECOMMENDED_ACCOUNTS_LIMIT))
    render json: recommendations, each_serializer: REST::AccountSerializer
  end

  private

  # Parse acct parameter
  # return account if local user
  # return 404 if not a local user
  def set_account
    username, domain = username_and_domain(params[:acct])
    return not_found unless TagManager.instance.local_domain?(domain)

    @account = Account.find_local(username)
  end

  def handle_to_account_remote(handle)
    username, domain = username_and_domain(handle)
    Account.find_remote(username, domain)
  end
end
