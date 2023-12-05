# frozen_string_literal: true

class Api::V3::Admin::ForYouController < Api::BaseController
  before_action :require_mammoth!

  # Ability to Trigger a rebuild from
  # Feature or Account Relay
  def update
    user_account = @decoded['sub']
    UpdateForYouWorker.set(queue: 'mammoth_critial').perform_async({ acct: user_account, rebuild: true })
  end
end
