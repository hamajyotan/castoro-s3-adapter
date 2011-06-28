begin
  require "rspec"
rescue LoadError
  require "rubygems" unless ENV["NO_RUBYGEMS"]
  gem "rspec"
  require "rsepc"
end

$:.unshift(File.dirname(__FILE__) + "/../lib")
require "castoro-s3-adapter"

