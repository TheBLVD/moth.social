# frozen_string_literal: true

class Api::V3::Timelines::ChannelsController < Api::BaseController
  before_action :set_channel

  after_action :insert_pagination_headers, only: [:show], unless: -> { @statuses.empty? }

  rescue_from Mammoth::Channels::NotFound do |e|
    render json: { error: e.to_s }, status: 404
  end

  def show
    if channel_id_param == '1efe873b-0bc2-454f-9f24-a9b8b8ef3410'
        response = HTTP.get(
          'https://feature.moth.social/listrelay/ThreadsDevs', :params => {
              :max_id => params[:max_id],
              :min_id => params[:min_id],
              :since_id => params[:since_id],
              :limit => params[:limit]
          }
        )
        raise NotFound, 'channel not found' unless response.code == 200

        @statuses = []
        render plain: response.body.to_s, content_type: "application/json"
        return
    end
    @statuses = cached_channel_statuses
    render json: @statuses,
           each_serializer: REST::StatusSerializer,
           relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
  end

  private

  def set_channel
    @mammoth = Mammoth::Channels.new
    @channel = @mammoth.find(channel_id_param)
  end

  def cached_channel_statuses
    cache_collection channel_statuses, Status
  end

  # LIST_LIMT set in Api::BaseController
  def channel_statuses
    channel_feed.get(DEFAULT_STATUSES_LIST_LIMIT,
                     params[:max_id],
                     params[:since_id],
                     params[:min_id])
  end

  def channel_feed
    MammothChannelFeed.new(@channel)
  end

  def channel_id_param
    params.require(:id)
  end

  # PAGINATION
  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:limit).permit(:limit).merge(core_params)
  end

  def next_path
    api_v3_timelines_channel_url pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v3_timelines_channel_url pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
