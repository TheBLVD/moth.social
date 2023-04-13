# frozen_string_literal: true

class Api::V1::Emails::ConfirmationsController < Api::BaseController
  before_action -> { doorkeeper_authorize! :write, :'write:accounts' }
  before_action :require_user_owned_by_application!
  before_action :require_user_not_confirmed!

  def create
    current_user.update!(email: params[:email]) if params.key?(:email)
    current_user.resend_confirmation_instructions

    render_empty
  end

  private

  def require_user_owned_by_application!
    unless current_user && current_user.created_by_application_id == doorkeeper_token.application_id
      render json: { error: 'This method is only available to the application the user originally signed-up with' },
             status: :forbidden
    end
  end

  def require_user_not_confirmed!
    unless !current_user.confirmed? || current_user.unconfirmed_email.present?
      render json: { error: 'This method is only available while the e-mail is awaiting confirmation' },
             status: :forbidden
    end
  end
end
