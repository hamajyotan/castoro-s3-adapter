
ENV['RACK_ENV'] = 'test'
require File.expand_path('../../config/application', __FILE__)

require 'rspec'
require 'rack/test'

def app
  S3Adapter::Controller
end

ActiveRecord::Base.logger.level = Logger::INFO

