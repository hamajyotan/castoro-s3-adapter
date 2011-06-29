
require "castoro-s3-adapter"

require "time"
require "sinatra/base"
require "builder"

module Castoro::S3Adapter #:nodoc:

  # URI dispatch control class based on Sinatra::Base
  #
  class Dispatcher < Sinatra::Base

    def initialize logger, client
      @logger, @client, = logger, client
      super()
    end

    set :views, File.dirname(__FILE__) + "/templates"

    helpers do
      include Adaptable
    end

    # GET Bucket
    get "/:bucket" do |bucket|
      @logger.debug { "GET Bucket - #{bucket}" }
      @bucket = bucket

      if (dir = get_basket(bucket))
        @files = Dir[File.join(dir, "*")].inject({}) { |h, f|
          h[f] = File.stat(f)
          h
        }
        builder :list_bucket_result
      else
        status 404
        builder :no_such_bucket
      end
    end

    # GET Object
    get "/:bucket/:object" do |bucket, object|
      @logger.debug { "GET Object - #{bucket}, #{object}" }

      if (dir = get_basket(bucket))
        if (file = get_basket_file(bucket, object))
          body File.open(file, "rb") { |f| f.read }
        else
          status 404
          builder :no_such_object
        end       
      else
        status 404
        builder :no_such_bucket
      end
    end

  end

end

