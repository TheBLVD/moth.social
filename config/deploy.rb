# frozen_string_literal: true

lock '3.17.1'

set :repo_url, ENV.fetch('REPO', 'git@github.com:TheBLVD/moth.social.git')
set :branch, ENV.fetch('BRANCH', 'main')

set :application, 'mastodon'
set :rbenv_type, :user
set :rbenv_ruby, File.read('.ruby-version').strip
set :migration_role, :app

append :linked_dirs, 'vendor/bundle', 'public/system'

namespace :systemd do
  %i[sidekiq streaming web].each do |service|
    %i[reload restart status].each do |action|
      desc "Perform a #{action} on #{service} service"
      task "#{service}:#{action}".to_sym do
        on roles(:web) do
          # runs e.g. "sudo restart mastodon-sidekiq.service"
          sudo :systemctl, action, "#{fetch(:application)}-#{service}.service"
        end
      end
    end
  end
end

# Restart services one at a time
after 'deploy', 'systemd:web:restart'
after 'systemd:web:restart', 'systemd:sidekiq:restart'
after 'systemd:sidekiq:restart', 'systemd:streaming:restart'
