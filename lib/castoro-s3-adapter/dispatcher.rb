
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

      unless @base_bucket == @bucket
        status 404
        return builder :no_such_bucket
      end

      basket, file_prefix = @prefix =~ /^(.+)\/(.*)$/ ? [$1, $2] : [nil, nil]
      return builder :list_bucket_result unless basket
 
      dir = get_basket basket

      @contents =
        if dir
          contents = []
          if file_prefix == ""
            st = File.stat(dir)
            contents << {
              :key => File.join(basket, "/"),
              :last_modified => st.mtime.utc.iso8601,
              :etag => sprintf("%x-%x-%x", st.ino, st.size, st.mtime),
              :size => 0,
              :storage_class => "STANDARD",
            }
          end

          Dir[File.join(dir, "**/*")].select { |f|
            f =~ /#{dir}#{file_prefix}.*$/
          }.each { |f|
            st = File.stat(f)
            contents << {
              :key => File.join(basket, File.basename(f)),
              :last_modified => st.mtime.utc.iso8601,
              :etag => sprintf("%x-%x-%x", st.ino, st.size, st.mtime),
              :size => st.size,
              :storage_class => "STANDARD",
            }
          }
          contents
        end.to_a

      @common_prefixes =                  
        if @delimiter
          @common_prefixes = @contents.map { |c|
            $1 if c[:key] =~ /^(#{@prefix}.*?#{@delimiter}).*$/
          }.uniq.compact.map { |p|
            { :prefix => p }
          }
        end.to_a

      @contents.reject! { |c|
        @common_prefixes.any? { |p|
          c[:key] =~ /^#{p[:prefix]}.*$/
        }
      }

      @contents.sort! { |x, y| x[:key] <=> y[:key] }
      @common_prefixes.sort! { |x, y| x[:prefix] <=> y[:prefix] }

      builder :list_bucket_result
    end

    # GET Object
    get "/:bucket/:basket/:object" do |bucket, basket, object|
      @bucket = bucket
      @key    = "#{basket}/#{object}"

      unless @base_bucket == @bucket
        status 404
        return builder :no_such_bucket
      end

      unless (file = get_basket_file(basket, object))
        status 404
        return builder :no_such_key
      end

      st = File.stat(file)
      headers "last-modified" => st.mtime.httpdate,
              "etag" => sprintf("%x-%x-%x", st.ino, st.size, st.mtime)
      body File.open(file, "rb") { |f| f.read }
    end

    # DELETE Object(basket)
    delete "/:bucket/:basket/" do |bucket, basket|
      @bucket = bucket
      @key    = "#{basket}"

      unless @base_bucket == @bucket
        status 404
        return builder :no_such_bucket
      end

      unless find_basket(basket)
        status 204
        return
      end

      delete_basket basket
      status 204
    end

    # DELETE Object(file in basket)
    delete "/:bucket/:basket/:object" do |bucket, basket, object|
      @bucket = bucket
      @key    = "#{basket}/#{object}"

      unless @base_bucket == @bucket
        status 404
        return builder :no_such_bucket
      end

      unless get_basket_file(basket, object)
        status 204
        return
      end

      status 403
      builder :access_denied
    end
    
    # DELETE Object(file)
    delete "/:bucket/:object" do |bucket, object|
      @bucket = bucket
      @key    = "#{object}"

      unless @base_bucket == @bucket
        status 404
        return builder :no_such_bucket
      end

      status 403
      builder :access_denied
    end

  end

end

