
ENV['RACK_ENV'] = 'test'

# boot.
require File.expand_path('../../config/boot', __FILE__)

# redefined castoro-client
require 'monitor'
module Castoro
  class Client
    @@temp_dir = File.expand_path('../../spec/tmp', __FILE__)
    S3Adapter::Adapter::BASE.replace @@temp_dir

    def initialize conf = {}
      @locker = Monitor.new
      @alive = false
      @sid = 0

      if block_given?
        self.open
        begin
          yield self
        ensure
          self.close
        end
      end
    end
    def open
      @locker.synchronize {
        raise ClientError, "client already opened." if opened?
        @alive = true
      }
    end
    def close
      @locker.synchronize {
        raise ClientError, "client already closed." if closed?
        @alive = false
      }
    end

    def opened?; @locker.synchronize { !! @alive }; end
    def closed?; ! opened?; end
    def sid
      @locker.synchronize { @sid }
    end

    def get key
      @locker.synchronize {
        path = File.join(@@temp_dir, "host", key.to_s)
        raise ClientTimeoutError, "command timeout" unless File.exist?(path)
        { "host" => key.to_s }
      }
    end
    def create key, hints = {}
      @locker.synchronize {
        dir = File.join(@@temp_dir, "host", key)
        raise ClientAlreadyExistsError, "[key:#{key}] Basket already exists in peers" if File.exist?(dir)
        FileUtils.mkdir_p dir
        yield "host", key
      }
    end
    def delete key
      get(key).each { |k,v|
        FileUtils.rm_r File.join(@@temp_dir, k, v) if File.directory?(File.join(@@temp_dir, k, v))
      }
    end
  end
end

# application.
require File.expand_path('../../config/application', __FILE__)

require 'rspec'
require 'rack/test'

# redifined Rack::Test:: Methods
module Rack
  module Test
    class Session
      def get(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "GET", :params => params))
        env["QUERY_STRING"] = URI.parse(uri).query.to_s
        process_request(uri, env, &block)
      end
    end
  end
end

def app
  S3Adapter::Controller
end

ActiveRecord::Base.logger.level = Logger::INFO

