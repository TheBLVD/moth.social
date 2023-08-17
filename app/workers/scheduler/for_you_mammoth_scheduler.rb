# frozen_string_literal: true

require 'http'
require 'json'

# Get mammoth users from AcctRelay
# Send each user acct to the update foryou worker
class Scheduler::ForYouMammothScheduler
  include Sidekiq::Worker
  include Async

  sidekiq_options retry: 0

  def perform
    users = mammoth_users.wait
    users.each do |acct|
      Rails.logger.debug { ">>>>>USERS:: #{acct}" }
      UpdateForYouWorker.perform_async({ acct: acct, rebuild: false })
    end
  end

  private

  # Fetch acct of mammoth users from AcctRelay
  def mammoth_users
    personal_for_you = PersonalForYou.new
    Async do
      personal_for_you.acct_relay_users
    end
  end
end
