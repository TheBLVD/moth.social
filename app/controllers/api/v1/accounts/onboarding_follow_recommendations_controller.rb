# frozen_string_literal: true

# Not to be confused with [Api::V1::Accounts::FollowRecommendationsController].
# This API suggests a hardcoded list of follows for new users while they are going through the
# onboarding flow after signing up for a new account.
# FollowRecommendationsController is used, instead, to suggest new follows to existing users based on
# their *current* list of followed accounts.
class Api::V1::Accounts::OnboardingFollowRecommendationsController < Api::BaseController
  def index
    render json: onboarding_follow_recommendations, each_serializer: REST::AccountSerializer
  end

  def onboarding_follow_recommendations
    OnboardingFollowRecommendationCategory.all.flat_map(&:accounts)
  end
end
