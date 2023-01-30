# frozen_string_literal: true

# Not to be confused with [Api::V1::Accounts::FollowRecommendationsController].
# This API suggests a hardcoded list of follows for new users while they are going through the
# onboarding flow after signing up for a new account.
# FollowRecommendationsController is used, instead, to suggest new follows to existing users based on
# their *current* list of followed accounts.
class Api::V1::OnboardingFollowRecommendationsController < Api::BaseController
  def index
    render json: onboarding_follow_recommendations, each_serializer: REST::FollowRecommendationCategorySerializer
  end

  private

  def onboarding_follow_recommendations
    categories = YAML.load_file(yaml_file_location)
    categories.map do |category|
      Onboarding::FollowRecommendationCategory.new(
        name: category['name'],
        theme_color: category['color'],
        # If any of YML accounts are invalid or not found in the database, we'll omit them from the response
        accounts: category['accounts']
          .map { |a| { account: Account.find_remote(*username_and_domain(a['account'])), summary: a['summary'] } }
          .reject { |a| a[:account].nil? }
      )
    end
  end

  def yaml_file_location
    "#{Rails.root}/app/lib/onboarding/onboarding_categories_#{Rails.env}.yml"
  end
end
