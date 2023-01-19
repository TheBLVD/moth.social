# frozen_string_literal: true

namespace :db do
  namespace :migrate do
    desc 'Setup the db or migrate depending on state of db'
    task setup: :environment do
      begin
        if ActiveRecord::Migrator.current_version.zero?
          Rake::Task['db:migrate'].invoke
          Rake::Task['db:seed'].invoke
        end
      rescue ActiveRecord::NoDatabaseError
        Rake::Task['db:setup'].invoke
      else
        Rake::Task['db:migrate'].invoke
      end
    end
  end

  task :pre_migration_check do
    version = ActiveRecord::Base.connection.select_one("SELECT current_setting('server_version_num') AS v")['v'].to_i
    abort 'This version of Mastodon requires PostgreSQL 9.5 or newer. Please update PostgreSQL before updating Mastodon' if version < 90_500
  end

  Rake::Task['db:migrate'].enhance(['db:pre_migration_check'])

  # based on https://gist.github.com/amit/45e750edde94b70431f5d42caadee423
  desc 'generate pg backups'
  task backup: :environment do
    db = ActiveRecord::Base.connection_db_config.database
    host = ActiveRecord::Base.connection_db_config.host
    username = ActiveRecord::Base.connection_db_config.configuration_hash[:username] || '""'
    password = ActiveRecord::Base.connection_db_config.configuration_hash[:password]

    backup_dir = "#{Rails.root}/backups"
    sh "mkdir -p #{backup_dir}"
    file_name = "#{backup_dir}/#{Time.now.utc.strftime('%Y%m%d%H%M%S')}_#{db}.dump"
    sh "PGPASSWORD=#{password} pg_dump -U #{username} -h #{host} -d #{db} -f #{file_name}"

    sh "aws s3 cp #{file_name} s3://moth-social/db_backups/"
  end
end
