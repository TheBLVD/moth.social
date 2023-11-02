# frozen_string_literal: true

class Api::V2::FollowRecommendationsGraphController < Api::BaseController
  RECOMMENDED_ACCOUNTS_LIMIT = 80
  INACTIVITY_DAYS_CUTOFF = 30

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
                      .reject { |recommendation| recommendation.last_status_at.nil? }
                      .reject { |recommendation| recommendation.last_status_at < Time.zone.today - INACTIVITY_DAYS_CUTOFF }
                      .take(limit_param(RECOMMENDED_ACCOUNTS_LIMIT))
    render json: recommendations, each_serializer: REST::AccountSerializer
  end

  private

  # Parse acct parameter
  # return account if personalized
  # return onboarding account suggestions of acct type is 'public'
  def set_account
    if acct_is_personalized?
      username, domain = username_and_domain(params[:acct])

      @account = if TagManager.instance.local_domain?(domain)
                   Account.find_local(username)
                 else
                   Account.find_remote(username, domain)
                 end
    else
      onboarding_accounts = OnboardingAccountRecommendationsService.new
      render json: onboarding_accounts.call, each_serializer: REST::AccountSerializer
    end
  end

  def acct_is_personalized?
    PersonalForYou.new.personalized_mammoth_user?(params[:acct])
  end

  def handle_to_account_remote(handle)
    username, domain = username_and_domain(handle)
    Account.find_remote(username, domain)
  end
end
