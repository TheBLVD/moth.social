# frozen_string_literal: true

class Api::V3::ChannelsController < Api::BaseController
  rescue_from Mammoth::Channels::NotFound do |e|
    render json: { error: e.to_s }, status: 404
  end

  def index
    @mammoth = Mammoth::Channels.new
    channels_result = @mammoth.list
    render json: channels_result
  end

  def show
    @mammoth = Mammoth::Channels.new
    channel = @mammoth.find(channel_id_param)
    render json: channel
  end

  def subscribe
    @mammoth = Mammoth::Channels.new
    @user = @mammoth.subscribe(channel_id_param, acct_param)
    render json: @user
  end

  def unsubscribe
    @mammoth = Mammoth::Channels.new
    @user = @mammoth.unsubscribe(channel_id_param, acct_param)
    render json: @user
  end

  private

  def channel_id_param
    params.require(:id)
  end

  def acct_param
    params.require(:acct)
  end
end
