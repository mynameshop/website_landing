set_default(:postgresql_host, "localhost")
set_default(:postgresql_user) { application }
set_default(:postgresql_password) { Capistrano::CLI.password_prompt "PostgreSQL Password: " }
set_default(:postgresql_database) { "#{application}_#{rails_env}" }
set_default(:postgresql_pid) { "/var/run/postgresql/9.1-main.pid" }

namespace :postgresql do
  desc "Install the latest stable release of PostgreSQL."
  task :install, roles: :db, only: { primary: true } do
    run "#{sudo} add-apt-repository -y ppa:pitti/postgresql"
    run "#{sudo} apt-get -y update"
    run "#{sudo} apt-get -y install postgresql libpq-dev"
  end
  after "deploy:install", "postgresql:install"
  
  desc "Create a database for this application"
  task :create_database, roles: :db, only: {primary: true} do
    run %Q{#{sudo} -u postgres psql -c "create user #{postgresql_user} with password '#{postgresql_password}';"}
    run %Q{#{sudo} -u postgres psql -c "create database #{postgresql_database} owner #{postgresql_user};"}
    run %Q{echo "localhost:*:#{postgresql_database}:#{postgresql_user}:#{postgresql_password}" > /home/#{user}/.pgpass}
    run %Q{chmod 0600 /home/#{user}/.pgpass}
  end
  after "deploy:setup", "postgresql:create_database"
  
  desc "Generate the database.yml config file"
  task :setup, roles: :app do
    run "mkdir -p #{shared_path}/config"
    run "mkdir -p #{shared_path}/db/backups"
    template "postgresql.yml.erb", "#{shared_path}/config/database.yml"
  end
  after "deploy:setup", "postgresql:setup"

  desc "Backup the database to S3"
  task :backup, roles: :app do
    run_remote "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake pg:backup"
  end

  desc "Restore the most recent production database from S3"
  task :restore_latest, roles: :app do
    run_remote "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake pg:restore_latest"
  end

  desc "Symlink the database.yml file into the latest release"
  task :symlink, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/db/backups #{release_path}/db/backups"
  end
  after "deploy:finalize_update", "postgresql:symlink"
end
