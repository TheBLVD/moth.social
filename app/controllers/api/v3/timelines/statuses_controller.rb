# frozen_string_literal: true

class Api::V3::Timelines::StatusesController < Api::BaseController
  before_action :set_status

  def show
    render json: { id: status_id_param }
  end

  private

  def set_status; end

  def status_id_param
    params.require(:id)
  end
end
