
namespace :db do
  desc "Migrate the database (options: VERSION=x, VERBOSE=false)."
  task :migrate do
    ActiveRecord::Migrator.migrate("db/migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end

  desc "Rolls the schema back to the previous version (specify steps w/ STEP=n)."
  task :rollback do
    ActiveRecord::Migrator.rollback("db/migrate/")
  end
end

