# frozen_string_literal: true

class Api::V3::ChannelsController < Api::BaseController
  def index
    @mammoth = Mammoth::Channels.new
    channels_result = @mammoth.list
    render json: channels_result
  end

  def show
    @mammoth = Mammoth::Channels.new
    @channel = @mammoth.find(channel_id_param)
    render json: @channel
  end

  def channel_id_param
    params.require(:id)
  end
end
