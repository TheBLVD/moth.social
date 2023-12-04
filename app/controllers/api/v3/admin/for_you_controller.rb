# frozen_string_literal: true

class Api::V3::Admin::ForYouController < Api::BaseController
  #   before_action :require_mammoth!

  # Ability to Trigger a rebuild from
  # Feature or Account Relay
  def update
    # Set Queue specificly for a rebuild
    Rails.logger.debug { "DECODED #{@decoded}" }
    UpdateForYouWorker.set(queue: 'mammoth_critial').perform_async({ acct: acct_param, rebuild: true })
  end
end
