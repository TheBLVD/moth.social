# frozen_string_literal: true

class Api::V3::Timelines::StatusesController < Api::BaseController
  rescue_from Mammoth::StatusOrigin::NotFound do |e|
    render json: { error: e.to_s }, status: 404
  end

  def show
    origin = Mammoth::StatusOrigin.instance
    @origins = origin.find(status_id_param)
    render json: @origins, each_serializer: StatusOriginSerializer
  end

  private

  def status_id_param
    params.require(:id)
  end
end
