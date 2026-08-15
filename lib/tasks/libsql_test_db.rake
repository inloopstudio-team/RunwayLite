# libsql adapter doesn't implement db:test:purge or db:test:load_schema.
# Override db:test:prepare to simply run pending migrations in the test env.
if defined?(ActiveRecord::ConnectionAdapters::LibsqlAdapter)
  Rake::Task["db:test:prepare"].clear if Rake::Task.task_defined?("db:test:prepare")

  namespace :db do
    namespace :test do
      task prepare: :environment do
        orig_env = Rails.env
        Rails.env = ActiveSupport::StringInquirer.new("test")
        ActiveRecord::Base.establish_connection(:test)
        ActiveRecord::MigrationContext.new(
          ActiveRecord::Migrator.migrations_paths,
          ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
        ).migrate
        ActiveRecord::Base.establish_connection(orig_env.to_sym)
        Rails.env = orig_env
      end
    end
  end
end
