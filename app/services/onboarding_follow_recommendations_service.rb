# frozen_string_literal: true

# Returns an array of string user handles (eg: johndoe@mastodon.server) with follow recommendations
# for the provided user, according to other users that are the most followed by their existing follows.
class OnboardingFollowRecommendationsService < BaseService
  def call
    generate_onboarding_follow_recommendations
  end

  private

  def generate_onboarding_follow_recommendations
    categories = YAML.load_file(yaml_file_location)
    categories.map do |category|
      Onboarding::V2::FollowRecommendationCategory.new(
        name: category['name'],
        # If any of YML accounts are invalid or not found in the database, we'll omit them from the response
        items: category['items'].filter_map do |item|
          if item['type'] == 'account'
            account = find_account(item)
            next if account.nil?
            { name: account,
              type: :account,
              summary: item['summary'] }
          elsif item['type'] == 'hashtag'
            { hashtag: item['hashtag'],
              type: :hashtag,
              summary: item['summary'],
              bio: item['bio'] }
          end
        end
      )
    end
  end

  def find_account(account)
    # TODO: this probably belongs in account_finder_concern.rb.
    # I'm putting it here for now to avoid messing with mastodon code.
    # if we need it elsewhere, we should move it. SD
    username, domain = username_and_domain(account['account'])
    Account.find_remote(username, domain) ||
      Account.find_local(username)
  end

  def username_and_domain(handle)
    username, domain = handle.strip.gsub(/\A@/, '').split('@')
    [username, domain]
  end

  def yaml_file_location
    "#{Rails.root}/app/lib/onboarding/v2/onboarding_categories_#{Rails.env}.yml"
  end
end
