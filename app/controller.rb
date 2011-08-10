
require 'digest'

module S3Adapter
  class Controller < Sinatra::Base

    set :environment, ENV['RACK_ENV']
    set :logging, true
    set :static, false
    set :views, File.dirname(__FILE__) + "/views"
    set :lock, true

    helpers do
      include S3Adapter::AuthorizationHelper

      ##
      # adopt_first_query_string
      #
      # If there are parameters of the same name, using the first specified value.
      def adopt_first_query_string
        request.query_string.split("&").inject({}) { |h,q|
          k, v = q.split("=", 2)
          h[k] = v unless h.include?(k)
          h
        }
      end

      def get_object basket, key
        modified_since   = Time.httpdate(env["HTTP_IF_MODIFIED_SINCE"]) rescue nil
        unmodified_since = Time.httpdate(env["HTTP_IF_UNMODIFIED_SINCE"]) rescue nil
        params = adopt_first_query_string

        # check bucket name.
        unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
          return 404, {}, builder(:no_such_bucket)
        end

        # get basket from database.
        unless (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
          return 404, {}, builder(:no_such_key)
        end

        last_modified = Time.parse(obj.last_modified)

        # get file from castoro.
        unless (file = Adapter.get_basket_file(obj.to_basket))
          return 404, {}, builder(:no_such_key)
        end

        # check if_unmodified_since
        if unmodified_since and unmodified_since < last_modified
          @condition = 'If-Unmodified-Since'
          return 412, {}, builder(:precondition_failed)
        end

        # check if_match
        if env["HTTP_IF_MATCH"] and obj.etag != env["HTTP_IF_MATCH"].gsub("\"", "")
          @condition = 'If-Match'
          return 412, {}, builder(:precondition_failed)
        end

        if env["HTTP_RANGE"] =~ /^bytes=(\d*)-(\d*)$/
          first, last = ($1.empty? ? 0 : $1.to_i), ($2.empty? ? obj.size-1 : $2.to_i)
          if obj.size <= first
            @message = "The requested range is not satisfiable"
            @actual_object_size = obj.size
            @range_requested = env["HTTP_RANGE"]
            return 416, {}, builder(:invalid_range)
          end
        end

        hs = {
          "last-modified" => last_modified.httpdate,
          "etag" => obj.etag,
          "accept-ranges" => "bytes",
          "content-type" => obj.content_type,
        }

        [
          "response-content-type",
          "response-content-language",
          "response-expires",
          "response-cache-control",
          "response-content-disposition",
          "response-content-encoding"
        ].each { |h|
          hs[h.sub("response-", "")] = params[h] if params[h]
        }

        # check if_none_match and if_modified_since
        if env["HTTP_IF_NONE_MATCH"] and modified_since
          return 304, hs, nil if obj.etag == env["HTTP_IF_NONE_MATCH"].gsub("\"", "") and last_modified <= modified_since
        elsif env["HTTP_IF_NONE_MATCH"] and obj.etag == env["HTTP_IF_NONE_MATCH"].gsub("\"", "")
          return 304, hs, nil
        elsif modified_since and last_modified <= modified_since
          return 304, hs, nil
        end

        if first or last
          hs["content-range"] = last < obj.size-1 ? "bytes #{first}-#{last}/#{obj.size}" : "bytes #{first}-#{obj.size-1}/#{obj.size}"
          return 206, hs, File.open(file, "rb") { |f| f.pos = first; f.read(last-first+1) }
        else
          return 200, hs, File.open(file, "rb") { |f| f.read }
        end
      end

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
        return builder(:invalid_argument)
      end
      @max_keys = @max_keys.to_i
      unless (0..2147483647).include? @max_keys
        @message = "Argument maxKeys must be an integer between 0 and 2147483647"
        @argument_value = @max_keys
        @argument_name = "maxKeys"
        return builder(:invalid_argument)
      end

      # check bucket name.
      unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
        status 404
        return builder(:no_such_bucket)
      end

      objects = S3Object.find(:all, :conditions => [ "path like ?", @prefix.to_s + '%' ] )
      @contents = objects.map { |o|
        {
          :key => o.path,
          :last_modified => o.last_modified,
          :etag => o.etag,
          :size => o.size,
          :storage_class => "STANDARD",
        }
      }

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

      @truncated = (@contents.size + @common_prefixes.size) > @max_keys

      builder(:list_bucket_result)
    end

    # HEAD Object
    # response body is nil.
    head %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key
      s, h, b = get_object bucket, key

      status s
      headers h
      body nil
    end

    # GET Object
    get %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key
      s, h, b = get_object bucket, key

      status s
      headers h
      body b
    end

    # DELETE Object
    delete %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key

      # check bucket name.
      unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
        status 404
        return builder(:no_such_bucket)
      end

      # get basket from database.
      unless (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
        status 204
        return nil
      end
      basket = obj.to_basket

      # get file from castoro.
      unless (file = Adapter.get_basket_file(basket))
        status 204
        return nil
      end

      # delete basket and database.
      Adapter.delete_basket_file basket
      obj.destroy

      status 204
      return nil
    end

    # PUT Object
    put %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key

      # check bucket name.
      unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
        status 404
        return builder(:no_such_bucket)
      end

      # set object value
      last_modified = Time.now.utc.iso8601
      body = request.body.read
      etag = Digest::MD5.hexdigest(body)
      size = body.size

      # get and create basket from database.
      if (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
        obj.basket_rev += 1
        obj.last_modified = last_modified
        obj.etag = etag
        obj.size = size
        obj.content_type = request.media_type
      else
        obj = S3Object.create { |o|
          o.basket_type = basket_type
          o.path = key
          o.basket_rev = 1
          o.last_modified = last_modified
          o.etag = etag
          o.size = size
          o.content_type = request.media_type
        }
      end
      obj.save
      basket = obj.to_basket

      # create basket to castoro.
      size = 0
      Adapter.put_basket_file(basket, request.body) { |readed_size|
        size += readed_size
      }

      status 200
      nil
    end

  end
end

