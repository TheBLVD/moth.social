# frozen_string_literal: true

# Force-reloads a user's follow recommendations list, that is, even if it's already cached, it will
# be invalidated and reloaded.
class FollowRecommendationsRefreshWorker
  include Sidekiq::Worker

  def perform(handle, limit)
    service = FollowRecommendationsService.new
    # Calling this method will have the side effect of force-caching the results in Redis
    handles = service.call(handle: handle, limit: limit, force: true)
    handles.each { |h| ResolveAccountWorker.perform_async(h) }
  end
end
