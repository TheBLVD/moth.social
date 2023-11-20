# frozen_string_literal: true

# Checks to see if UpdateForYouWokers are still running jobs from last
# scheduled batch.
# If jobs are found, Error is raised, rescued, logged & captured, then bubbled up
class ForYouMammothServiceCheck < BaseService
  class Error < StandardError; end

  def call
    begin
      update_worker_in_process?
    rescue Error => e
      Rails.logger.warn("error: #{e}")
      Appsignal.send_error(e) do |transaction|
        transaction.set_action('require_mammoth')
        transaction.set_namespace('for_you')
        transaction.params = { time: Time.now.utc, error: e }
      end
      raise e
    end
  end

  # Check specificly for any UpdateWorker
  # in the 'mammoth_default' queue
  # rebuilds are sent to 'mammoth_critical'
  def update_worker_in_process?
    queue = Sidekiq::Queue.new('mammoth_default')

    raise Error, 'UpdateForYouWoker already running' if queue.any? do |job|
      job.klass == UpdateForYouWorker.to_s
    end
  end
end
