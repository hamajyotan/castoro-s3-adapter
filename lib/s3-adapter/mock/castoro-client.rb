
require 'rubygems'
require 'castoro-client'

require 'monitor'
module Castoro
  class Client
    @@temp_dir = File.expand_path(File.join('../../../../tmp/castoro', ENV['RACK_ENV']), __FILE__)
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
        dir = File.join(@@temp_dir, "host", key.to_s)
        raise ClientAlreadyExistsError, "[key:#{key.to_s}] Basket already exists in peers" if File.exist?(dir)
        FileUtils.mkdir_p dir
        yield "host", key.to_s
      }
    end
    def delete key
      get(key).each { |k,v|
        FileUtils.rm_r File.join(@@temp_dir, k, v) if File.directory?(File.join(@@temp_dir, k, v))
      }
    end
  end
end

