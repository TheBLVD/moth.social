# frozen_string_literal: true

# Checks to see if UpdateForYouWokers are still running jobs from last
# scheduled batch.
class ForYouMammothServiceCheck < BaseService
  def call
    update_worker_in_process?
  end

  # Check specificly for any UpdateWorker
  # in the 'mammoth_default' queue
  # rebuilds are sent to 'mammoth_critical'
  def update_worker_in_process?
    queue = Sidekiq::Queue.new('mammoth_default')

    queue.any? do |job|
      job.klass == UpdateForYouWorker.to_s
    end
  end
end
