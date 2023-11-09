# frozen_string_literal: true

require 'http'
require 'json'

# Get mammoth users from AcctRelay
# Send each user acct to the update foryou worker
class Scheduler::ForYouMammothScheduler
  include Sidekiq::Worker
  include Async

  sidekiq_options retry: 0

  LOAD_TEST_MULTIPLIER = ENV['FOR_YOU_LOAD_TEST_MULTIPLIER'].to_i || 1

  Rails.logger.warn "ForYouMammothScheduler LOAD TEST:: x#{LOAD_TEST_MULTIPLIER}" if LOAD_TEST_MULTIPLIER > 1

  def perform
    users = mammoth_users.wait
    users.flat_map { |u| [u] * LOAD_TEST_MULTIPLIER }
         .each do |acct|
      UpdateForYouWorker.perform_async({ acct: acct, rebuild: false })
    end
  end

  private

  # Fetch acct of mammoth users from AcctRelay
  # These are users that are 'personalize'
  def mammoth_users
    personal_for_you = PersonalForYou.new
    Async do
      personal_for_you.acct_relay_users
    end
  end
end
