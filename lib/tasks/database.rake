
namespace :db do
  task :connect do
    ActiveRecord::Base.establish_connection ENV['RACK_ENV']
  end

  desc "Migrate the database (options: VERSION=x, VERBOSE=false)."
  task :migrate => :connect do
    ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
    ActiveRecord::Migrator.migrate("db/migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end

  desc "Rolls the schema back to the previous version (specify steps w/ STEP=n)."
  task :rollback => :connect do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    ActiveRecord::Migrator.rollback('db/migrate/', step)
  end
end

