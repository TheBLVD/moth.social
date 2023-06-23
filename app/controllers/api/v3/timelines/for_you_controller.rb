# frozen_string_literal: true

class Api::V3::Timelines::ForYouController < Api::BaseController
  DEFAULT_STATUSES_LIST_LIMIT = 120
  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  LIST_TITLE = 'For You'
  MINIMUM_ENGAGMENT_ACTIONS = 2
  before_action :set_list
  before_action :set_statuses

  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  def show
    render json: @statuses,
           each_serializer: REST::StatusSerializer
  end

  private

  def set_list
    @owner_account = set_owner
    @list = List.where(account: @owner_account, title: LIST_TITLE).first!
  end

  def set_owner
    Account.local.where(username: FOR_YOU_OWNER_ACCOUNT)
  end

  # Combine engagment actions. Greater than the min engagement set.
  # Check status for reblog content or assign original content
  # Reject statues with a reply_to or poll_id
  # Return the default limit
  def set_statuses
    filtered_statuses = cached_list_statuses.select do |s|
      status = s.reblog? ? s.reblog : s
      status_counts = status.reblogs_count + status.replies_count + status.favourites_count
      status_counts >= MINIMUM_ENGAGMENT_ACTIONS && status.in_reply_to_id.nil? && status.poll_id.nil?
    end
    @statuses = filtered_statuses.take(limit_param(DEFAULT_STATUSES_LIST_LIMIT))
  end

  def cached_list_statuses
    cache_collection list_statuses, Status
  end

  def list_statuses
    list_feed.get(
      limit_param(1000),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )
  end

  def list_feed
    ListFeed.new(@list)
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:limit).permit(:limit).merge(core_params)
  end

  def next_path
    api_v2_timelines_for_you_url pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v2_timelines_for_you_url pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
