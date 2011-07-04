
require "castoro-s3-adapter"

require "time"
require "sinatra/base"
require "builder"

module Castoro::S3Adapter #:nodoc:

  # URI dispatch control class based on Sinatra::Base
  #
  class Dispatcher < Sinatra::Base

    def initialize logger, client, base_bucket
      @logger, @client, = logger, client
      @base_bucket = base_bucket
      super()
    end

    set :views, File.dirname(__FILE__) + "/templates"

    helpers do
      include Adaptable
    end

    # GET Bucket
    get %r{^/([\w]+)/?$} do |bucket|
      @bucket    = bucket
      @prefix    = params[:prefix]
      @marker    = params[:marker]
      @delimiter = params[:delimiter]
      @max_keys  = params["max-keys"] || 1000

      unless @max_keys.to_s =~ /^\-?[\d]+$/
        @message = "Provided max-keys not an integer or within integer range"
        @argument_value = @max_keys
        @argument_name = "max-keys"
        return builder :invalid_argument
      end
      @max_keys = @max_keys.to_i
      unless (0..2147483647).include? @max_keys
        @message = "Argument maxKeys must be an integer between 0 and 2147483647"
        @argument_value = @max_keys
        @argument_name = "maxKeys"
        return builder :invalid_argument
      end

      unless @bucket == bucket
        status 404
        return builder :no_such_bucket
      end

      basket, file_prefix = @prefix =~ /^(.+)\/(.*)$/ ? [$1, $2] : [nil, nil]
      unless basket
        @files = {}
        return builder :list_bucket_result
      end
 
      unless (dir = get_basket(basket))
        status 404
        return builder :no_such_object
      end

      @contents = []
      if file_prefix == ""
        st = File.stat(dir)
        @contents << {
          :key => File.join(basket, "/"),
          :last_modified => st.mtime.utc.iso8601,
          :etag => nil,
          :size => 0,
          :storage_class => "STANDARD",
        }
      end

      Dir[File.join(dir, "**/*")].select { |f|
        f =~ /#{dir}#{file_prefix}.*$/
      }.each { |f|
        st = File.stat(f)
        @contents << {
          :key => File.join(basket, File.basename(f)),
          :last_modified => st.mtime.utc.iso8601,
          :etag => nil,
          :size => st.size,
          :storage_class => "STANDARD",
        }
      }

      @contents.sort_by! { |c| c[:key] }

      @common_prefixes = []
      if @delimiter
        @common_prefixes = @contents.map { |c|
          $1 if c[:key] =~ /^(#{@prefix}.*?#{@delimiter}).*$/
        }.uniq.compact.map { |p|
          { :prefix => p }
        }
      end

      @contents.reject! { |c|
        @common_prefixes.any? { |p|
          c[:key] =~ /^#{p[:prefix]}.*$/
        }
      }

      @common_prefixes.sort_by! { |p| p[:prefix] }

      builder :list_bucket_result
    end

    # GET Object
    get "/:bucket/:basket/:object" do |bucket, basket, object|
      @bucket = bucket
      @response_content_type        = params["response-content-type"]
      @response_content_language    = params["response-content-language"]
      @response_expires             = params["response-expires"]
      @response_cache_control       = params["response-cache-control"]
      @response_content_disposition = params["response-content-disposition"]
      @response_content_encoding    = params["response-content-encoding"]

      unless @bucket == bucket
        status 404
        return builder :no_such_bucket
      end

      unless (file = get_basket_file(basket, object))
        status 404
        return builder :no_such_object
      end

      body File.open(file, "rb") { |f| f.read }
    end

  end

end

