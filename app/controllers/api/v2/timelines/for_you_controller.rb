# frozen_string_literal: true

class Api::V2::Timelines::ForYouController < Api::BaseController
  FOR_YOU_OWNER_ACCOUNT = ENV['FOR_YOU_OWNER_ACCOUNT'] || 'admin'
  LIST_TITLE = 'For You'
  MINIMUM_REBLOG = 1
  MINIMUM_FAVORITE = 1
  MINIMUM_REPLIES = 1

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

  def set_statuses
    @statuses = cached_list_statuses
  end

  def cached_list_statuses
    cache_collection list_statuses, Status
  end

  def list_statuses
    statuses = list_feed.get(
      limit_param(2000),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )

    statuses.select do |status|
      status.reblogs_count >= MINIMUM_REBLOG ||
        status.replies_count >= MINIMUM_REPLIES ||
        status.favourites_count >= MINIMUM_FAVORITE
    end.first(DEFAULT_STATUSES_LIMIT)
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
