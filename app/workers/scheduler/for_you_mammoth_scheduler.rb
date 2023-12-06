# frozen_string_literal: true

require 'http'
require 'json'

# Get mammoth users from AcctRelay
# Send each user acct to the update foryou worker
class Scheduler::ForYouMammothScheduler
  include Sidekiq::Worker
  include Async

  sidekiq_options retry: 0

  # Specific to Load testing
  LOAD_TEST_MULTIPLIER = ENV['FOR_YOU_LOAD_TEST_MULTIPLIER'].to_i || 1
  Rails.logger.warn "ForYouMammothScheduler LOAD TEST:: x#{LOAD_TEST_MULTIPLIER}" if LOAD_TEST_MULTIPLIER > 1

  def perform
    # Check for existing UpdateForYou Workers first
    ForYouMammothServiceCheck.new.call

    users = mammoth_users.wait
    users.flat_map { |u| [u] * LOAD_TEST_MULTIPLIER }
         .each do |acct|
      UpdateForYouWorker.perform_async({ acct: acct, rebuild: false })
    end
  end

  private

  # Fetch acct of mammoth users from AcctRelay
  # These are users that are 'local' & ordered by last Active
  def mammoth_users
    m_users = Mammoth::Users.new
    Async do
      m_users.all_mammoth_users
    end
  end
end
