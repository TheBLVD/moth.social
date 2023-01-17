# frozen_string_literal: true

# Force-reloads a user's follow recommendations list, that is, even if it's already cached, it will
# be invalidated and reloaded.
class FollowRecommendationsRefreshWorker
  include Sidekiq::Worker

  def perform(handle, limit)
    recommendations = FollowRecommendations.new(handle: handle, limit: limit)
    # Calling this method will have the side effect of force-caching the results in Redis
    recommendations.account_indirect_follows(force: true)
  end
end
