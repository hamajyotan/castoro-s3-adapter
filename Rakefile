
require File.expand_path('../config/boot', __FILE__)
require 'rake'

Dir.glob(File.expand_path('../lib/tasks/**/*.rake', __FILE__)).each { |rakefile|
  load rakefile
}

task :default => :spec

