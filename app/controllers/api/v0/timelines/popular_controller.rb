# frozen_string_literal: true

class Api::V0::Timelines::PopularController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:statuses' }, only: [:show]
  before_action :require_user!, only: [:show]
  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  def show
    @statuses = sorted_statuses

    render json: @statuses,
           each_serializer: REST::StatusSerializer,
           relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id),
           status: account_popular_feed.regenerating? ? 206 : 200
  end

  private

  def sorted_statuses
    load_statuses.sort_by(&:popularity)
  end

  def load_statuses
    cached_popular_statuses
  end

  def cached_popular_statuses
    cache_collection popular_statuses, Status
  end

  def popular_statuses
    account_popular_feed.get(
      limit_param(DEFAULT_STATUSES_LIMIT),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )
  end

  def account_popular_feed
    HomeFeed.new(current_account)
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:local, :limit).permit(:local, :limit).merge(core_params)
  end

  def next_path
    api_v0_timelines_popular_url pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v0_timelines_popular_url pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
