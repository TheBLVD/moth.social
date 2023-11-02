# frozen_string_literal: true

# Returns an array of user accounts resolved from the onboard_follow_recommendations yml
class OnboardingAccountRecommendationsService < BaseService
  def call
    generate_onboarding_account_recommendations
  end

  private

  def generate_onboarding_account_recommendations
    categories = YAML.load_file(yaml_file_location)
    categories.flat_map do |category|
      # If any of YML accounts are invalid or not found in the database, we'll omit them from the response
      category['items'].filter_map do |item|
        if item['type'] == 'hashtag'
          next
        elsif item['type'] == 'account'
          account = find_account(item)
          next if account.nil?

          account
        end
      end
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
    Rails.root.join("app/lib/onboarding/v2/onboarding_categories_#{Rails.env}.yml").to_s
  end
end
