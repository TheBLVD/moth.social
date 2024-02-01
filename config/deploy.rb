# frozen_string_literal: true

lock '3.17.3'

set :repo_url, ENV.fetch('REPO', 'git@github.com:TheBLVD/moth.social.git')
set :branch, ENV.fetch('BRANCH', 'main')

set :application, 'mastodon'
set :rbenv_type, :user
set :rbenv_ruby, File.read('.ruby-version').strip
set :migration_role, :app
set :appsignal_config, name: 'moth.social'

append :linked_dirs, 'vendor/bundle', 'public/system'

SYSTEMD_SERVICES = %i[sidekiq streaming web].freeze
SERVICE_ACTIONS = %i[reload restart status].freeze

SYSTEMD_SERVICES = %i[sidekiq streaming web].freeze
SERVICE_ACTIONS = %i[reload restart status].freeze

namespace :systemd do
  SYSTEMD_SERVICES.each do |service|
    SERVICE_ACTIONS.each do |action|
      desc "Perform a #{action} on #{service} service"
      task "#{service}:#{action}".to_sym do
        on roles(:web) do
          # runs e.g. "sudo restart mastodon-sidekiq.service"
          sudo :systemctl, action, "#{fetch(:application)}-#{service}*"
        end
      end
    end
  end
end

# Restart services one at a time
after 'deploy', 'systemd:web:restart'
after 'systemd:web:restart', 'systemd:sidekiq:restart'
after 'systemd:sidekiq:restart', 'systemd:streaming:restart'
