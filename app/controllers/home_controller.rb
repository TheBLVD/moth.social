# frozen_string_literal: true

class HomeController < ApplicationController
  include WebAppControllerConcern

  before_action :set_instance_presenter

  def index
    expires_in 0, public: true unless user_signed_in?
  end

  def apple_app_site_association
    render formats: :json
  end

  private

  def set_instance_presenter
    @instance_presenter = InstancePresenter.new
  end
end
