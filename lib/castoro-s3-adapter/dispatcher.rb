
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
    get "/:bucket/" do |bucket|
      redirect "/#{bucket}"
    end

    # GET Bucket
    get "/:bucket" do |bucket|
      @logger.debug { "GET Bucket - #{bucket}" }
      @bucket = bucket

      if (@files = get_files(bucket))
        builder :get_bucket
      else
        builder :get_bucket_404
        status 404
      end
    end

    # GET Object
    get "/:bucket/:object" do |bucket, object|
      @logger.debug { "GET Object - #{bucket}, #{object}" }

      if (file = get_file(bucket, object))
        body File.open(file, "rb") { |f| f.read }
      else
        @object = object
        builder :get_object_404
        status 404
      end
    end

  end

end
