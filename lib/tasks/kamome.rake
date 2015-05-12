require 'active_record'

namespace :db do
  task :load_kamome_config do
    rails_env = ENV['RAILS_ENV'] || 'development'
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = Kamome.config.database_config
    ActiveRecord::Base.configurations       = ActiveRecord::Tasks::DatabaseTasks.database_configuration || {}
    ActiveRecord::Migrator.migrations_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths
  end

  desc 'Creates shard databases.'
  task "create:kamome" => %w(environment load_kamome_config) do |t, args|
    Kamome.config.shard_names.each do |name|
      ActiveRecord::Tasks::DatabaseTasks.create_current name
    end
  end

  desc 'Drops shard databases.'
  task "drop:kamome" => %w(environment load_kamome_config) do |t, args|
    Kamome.config.shard_names.each do |name|
      ActiveRecord::Tasks::DatabaseTasks.drop_current name
    end
  end

  desc "Migrate shards database (options: VERSION=x, VERBOSE=false, SCOPE=blog)."
  task "migrate:kamome" => %w(environment load_kamome_config) do
    Kamome.config.shard_names.each do |name|
      ActiveRecord::Tasks::DatabaseTasks.env = ActiveSupport::StringInquirer.new(name)
      ActiveRecord::Base.establish_connection name.to_sym
      ActiveRecord::Tasks::DatabaseTasks.migrate
    end
  end

  namespace :migrate do
    desc 'Display shards status of migrations'
    task "status:kamome" => %w(environment load_kamome_config) do
      Kamome.config.shard_names.each do |name|
        ActiveRecord::Tasks::DatabaseTasks.env = ActiveSupport::StringInquirer.new(name)
        ActiveRecord::Base.establish_connection name.to_sym
        unless ActiveRecord::SchemaMigration.table_exists?
          abort 'Schema migrations table does not exist yet.'
        end
        db_list = ActiveRecord::SchemaMigration.normalized_versions

        file_list =
          ActiveRecord::Migrator.migrations_paths.flat_map do |path|
          # match "20091231235959_some_name.rb" and "001_some_name.rb" pattern
          Dir.foreach(path).grep(/^(\d{3,})_(.+)\.rb$/) do
            version = ActiveRecord::SchemaMigration.normalize_migration_number($1)
            status = db_list.delete(version) ? 'up' : 'down'
            [status, version, $2.humanize]
          end
        end

        db_list.map! do |version|
          ['up', version, '********** NO FILE **********']
        end
        # output
        puts "\ndatabase: #{ActiveRecord::Base.connection_config[:database]}\n\n"
        puts "#{'Status'.center(8)}  #{'Migration ID'.ljust(14)}  Migration Name"
        puts "-" * 50
        (db_list + file_list).sort_by { |_, version, _| version }.each do |status, version, name|
          puts "#{status.center(8)}  #{version.ljust(14)}  #{name}"
        end
        puts
      end
    end
  end
end
