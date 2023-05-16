# frozen_string_literal: true

# Not to be confused with [Api::V1::Accounts::FollowRecommendationsController].
# This API suggests a hardcoded list of follows for new users while they are going through the
# onboarding flow after signing up for a new account.
# FollowRecommendationsController is used, instead, to suggest new follows to existing users based on
# their *current* list of followed accounts.
class Api::V2::OnboardingFollowRecommendationsController < Api::BaseController
  def index
    onboarding_follows = OnboardingFollowRecommendationsService.new
    render json: onboarding_follows.call, each_serializer: REST::V2::FollowRecommendationCategorySerializer
  end
end
