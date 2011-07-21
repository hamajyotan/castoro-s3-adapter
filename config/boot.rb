
require 'logger'
require 'yaml'

require 'rubygems'
require 'sinatra/base'
require 'builder'
require 'castoro-client'
require 'active_record'

# RACK_ENV
ENV['RACK_ENV'] ||= 'development'

# It is not correctly converted by the influence of active_record.
class Castoro::Protocol::Command
  class Get
    def to_s; [ "1.1", "C", "GET", { "basket" => @basket.to_s } ].to_json + "\r\n"
    end
  end
  class Create
    def to_s; [ "1.1", "C", "CREATE", {"basket" => @basket.to_s, "hints" => @hints }].to_json + "\r\n"
    end
  end
  class Delete
    def to_s; [ "1.1", "C", "DELETE", { "basket" => @basket.to_s } ].to_json + "\r\n"
    end 
  end
  class Finalize
    def to_s; [ "1.1", "C", "FINALIZE", {"basket" => @basket.to_s, "host" => @host, "path" => @path}].to_json + "\r\n"
    end
  end
  class Cancel
    def to_s; [ "1.1", "C", "CANCEL", {"basket" => @basket.to_s, "host" => @host, "path" => @path}].to_json + "\r\n"
    end
  end
end

# add to $LOAD_PATH
$LOAD_PATH << File.expand_path('../../lib/', __FILE__)

# require models
Dir.glob(File.expand_path('../../app/models/*.rb', __FILE__)).each { |model| require model }

# require controller
require File.expand_path('../../app/controller', __FILE__)

# load configurations.
default_config = {
  "buckets" => {
    "castoro" => {
      "basket_type" => 999,
    },
  },
  "castoro-client" => nil,
}
S3CONFIG = default_config.merge!(YAML::load_file('config/s3-adapter.yml')[ENV['RACK_ENV']]).freeze

# database settings.
ActiveRecord::Base.configurations = YAML.load_file('config/database.yml')
ActiveRecord::Base.logger = Logger.new $stdout

