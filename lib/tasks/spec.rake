
require 'rubygems'

begin
  require 'rspec'
  require 'rspec/core/rake_task'

  desc "Run the specs under spec/"
  RSpec::Core::RakeTask.new do |t|
    t.pattern = "spec/**/*_spec.rb"
  end
  task :default => :spec

  desc "Run the specs under spec/"
  task :test => :spec

rescue LoadError
  # do nothing.
end

