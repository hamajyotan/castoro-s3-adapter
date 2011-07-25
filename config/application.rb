
require File.expand_path('../../config/boot', __FILE__)

# castoro-client init.
S3Adapter::Adapter.init

# database connection settings.
ActiveRecord::Base.establish_connection ENV['RACK_ENV']

