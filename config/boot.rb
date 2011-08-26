
require 'logger'
require 'yaml'

require 'rubygems'
require 'sinatra/base'
require 'builder'
require 'castoro-client'
require 'active_record'

# RACK_ENV
ENV['RACK_ENV'] ||= 'development'

# require initializers.
Dir.glob(File.expand_path('../../config/initializers/*.rb', __FILE__)).each { |init| require init }

# load configurations.
default_config = {
  "buckets" => {
    "castoro" => {
      "basket_type" => 999,
    },
  },
  "castoro-client" => nil,
}
S3CONFIG = default_config.merge!(
  YAML::load_file(File.expand_path('../../config/s3-adapter.yml', __FILE__))[ENV['RACK_ENV']]
).freeze

# add to $LOAD_PATH
$LOAD_PATH << File.expand_path('../../lib/', __FILE__)
require 's3-adapter'

# require models
Dir.glob(File.expand_path('../../app/models/*.rb', __FILE__)).each { |model| require model }

# require controller
require File.expand_path('../../app/controller', __FILE__)

# database settings.
ActiveRecord::Base.configurations = YAML.load_file(File.expand_path('../../config/database.yml', __FILE__))
ActiveRecord::Base.logger = Logger.new $stdout

