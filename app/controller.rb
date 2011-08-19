
require 'digest'

module S3Adapter
  class Controller < Sinatra::Base

    use Middleware::UrlRewrite, S3CONFIG['domain']
    use Middleware::InternalError
    use Rack::Head
    use Middleware::CommonHeader
    use Middleware::UniqueGetParameter
    use Middleware::Authorization, (S3CONFIG['users'] || {})

    set :environment, ENV['RACK_ENV']
    set :logging, true
    set :static, false
    set :views, File.dirname(__FILE__) + "/views"
    set :lock, true
    set :raise_errors, false

    helpers do
      def get_object basket, key
        modified_since   = Time.httpdate(env["HTTP_IF_MODIFIED_SINCE"]) rescue nil
        unmodified_since = Time.httpdate(env["HTTP_IF_UNMODIFIED_SINCE"]) rescue nil

        # check bucket name.
        unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
          return 404, {}, builder(:no_such_bucket)
        end

        # get basket from database.
        unless (obj = S3Object.active.find_by_basket_type_and_path(basket_type, key))
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
          "last-modified"       => last_modified.httpdate,
          "etag"                => obj.etag,
          "accept-ranges"       => "bytes",
        }
        hs["expires"]             = obj.expires if obj.expires
        hs["content-type"]        = obj.content_type if obj.content_type
        hs["cache-control"]       = obj.cache_control if obj.cache_control
        hs["content-encoding"]    = obj.content_encoding if obj.content_encoding
        hs["content-disposition"] = obj.content_disposition if obj.content_disposition

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

      def put_object key
        # check bucket name.
        unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
          return 404, builder(:no_such_bucket)
        end

        # set object value
        last_modified       = Time.now.utc.iso8601
        body                = request.body.read
        etag                = Digest::MD5.hexdigest(body)
        size                = body.size
        expect              = env['HTTP_EXPECT']
        expires             = env['HTTP_EXPIRES']
        content_type        = env['CONTENT_TYPE'] || "binary/octet-stream"
        content_length      = env['CONTENT_LENGTH']
        @content_md5        = env['HTTP_CONTENT_MD5']
        cache_control       = env['HTTP_CACHE_CONTROL']
        content_encoding    = env['HTTP_CONTENT_ENCODING']
        content_disposition = env['HTTP_CONTENT_DISPOSITION']

        # validate content_length
        unless content_length
          return 411, builder(:missing_content_length)
        end

        # valid content_length error
        content_length = Integer(env['CONTENT_LENGTH']) rescue (return 400, nil)

        # trancate request body by content_length
        if content_length.to_i < size.to_i
          size = content_length
          request.body.truncate(size)
        end

        # validate content-MD5
        if @content_md5 and @content_md5 != etag
          return 400, builder(:invalid_digest)
        end

        # get and create basket from database.
        if (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
          obj.basket_rev         += 1
          obj.etag                = etag
          obj.size                = size
          obj.last_modified       = last_modified
          obj.content_type        = content_type
          obj.expires             = expires if expires
          obj.cache_control       = cache_control if cache_control
          obj.content_encoding    = content_encoding if content_encoding
          obj.content_disposition = content_disposition if content_disposition
          obj.deleted             = false
        else
          obj = S3Object.create { |o|
            o.basket_type         = basket_type
            o.path                = key
            o.basket_rev          = 1
            o.etag                = etag
            o.size                = size
            o.last_modified       = last_modified
            o.content_type        = content_type
            o.expires             = expires if expires
            o.cache_control       = cache_control if cache_control
            o.content_encoding    = content_encoding if content_encoding
            o.content_disposition = content_disposition if content_disposition
          }
        end
        obj.save
        basket = obj.to_basket

        # create basket to castoro.
        size = 0
        Adapter.put_basket_file(basket, request.body) { |readed_size|
          size += readed_size
        }
        return 200, nil
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

      cs = []
      cs << "path like :prefix" unless @prefix.to_s.empty?
      cs << "path > :marker" unless @marker.to_s.empty?
      objects = S3Object.active.find(:all, :conditions => [cs.join(" and "), {:prefix => @prefix.to_s + '%', :marker => @marker.to_s}])
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

      if @truncated = (@contents.size + @common_prefixes.size) > @max_keys
        @next_marker = (
          @contents.map { |c| c[:key ] } + @common_prefixes.map { |p| p[:prefix] }
        ).sort[@max_keys - 1]

        @contents.reject! { |c| @next_marker < c[:key] }
        @common_prefixes.reject! { |p| @next_marker < p[:prefix] }
      end

      @contents.sort! { |x, y| x[:key] <=> y[:key] }
      @common_prefixes.sort! { |x, y| x[:prefix] <=> y[:prefix] }

      builder(:list_bucket_result)
    end

    # HEAD Object
    head %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key
      get_object bucket, key
    end

    # GET Object
    get %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key
      get_object bucket, key
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
      unless (obj = S3Object.active.find_by_basket_type_and_path(basket_type, key))
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
      obj.deleted = true
      obj.basket_rev += 1
      obj.save

      status 204
      return nil
    end

    # PUT Object
    put %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key
      s, b = put_object key

      status s
      body b
    end

  end
end

