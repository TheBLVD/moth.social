# frozen_string_literal: true

class Api::V3::Timelines::ChannelsController < Api::BaseController
  before_action :set_channel

  rescue_from Mammoth::Channels::NotFound do |e|
    render json: { error: e.to_s }, status: 404
  end

  def show
    @statuses = channel_statuses
    Rails.logger.info { "STATUSES>>>>> #{@statues}" }
    render json: @statuses,
           each_serializer: REST::StatusSerializer,
           relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
  end

  private

  def set_channel
    @mammoth = Mammoth::Channels.new
    @channel = @mammoth.find(channel_id_param)
    Rails.logger.info { "CHANNEL:::::: #{@channel}" }
  end

  def cached_channel_statuses
    cache_collection channel_statuses, Status
  end

  def channel_statuses
    channel_feed.get(limit_param(1000),
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
