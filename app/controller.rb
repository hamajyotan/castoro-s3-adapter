
require 'digest'

module S3Adapter
  class Controller < Sinatra::Base

    use Middleware::UrlRewrite, S3CONFIG['domain']
    use Middleware::InternalError
    use Rack::Head
    use Middleware::CommonHeader
    use Middleware::UniqueGetParameter
    use Middleware::Authorization

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

        # response-* headers
        unless request.GET.empty?
          [
            "response-cache-control",
            "response-content-disposition",
            "response-content-encoding",
            "response-content-language",
            "response-content-type",
            "response-expires",
          ].select { |q| params.include?(q) }.tap { |qs|

            if not qs.empty? and env['s3adapter.authorization'].nil?
              @message = "Request specific response headers cannot be used for anonymous GET requests."
              return 400, {}, builder(:invalid_request)
            end
          qs.each { |q| hs[q.sub("response-", "")] = params[q] }
          }
        end

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

      def put_object bucket, key
        # check bucket name.
        unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
          return 404, builder(:no_such_bucket)
        end

        # set object value
        last_modified       = DependencyInjector.time_now.utc.iso8601
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
          return 411, {"Content-Type" => "application/xml"}, builder(:missing_content_length)
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

        # create response headers.
        hs = { "etag" => etag, }
        return 200, hs, nil
      end

      def copy_object bucket, key
        hs = {"Content-Type" => "application/xml"}

        # check bucket name.
        unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
          return 404, hs, builder(:no_such_bucket)
        end

        # check authorization.
        unless env["s3adapter.authorization"]
          @message = "Anonymous users cannot copy objects.  Please authenticate."
          return 403, hs, builder(:access_denied)
        end

        # set object value.
        last_modified       = DependencyInjector.time_now.utc.iso8601
        expires             = env['HTTP_EXPIRES']
        content_type        = env['CONTENT_TYPE'] || "binary/octet-stream"
        content_length      = env['CONTENT_LENGTH']
        cache_control       = env['HTTP_CACHE_CONTROL']
        content_encoding    = env['HTTP_CONTENT_ENCODING']
        content_disposition = env['HTTP_CONTENT_DISPOSITION']

        # validate content_length.
        if (content_length and (content_length.to_i > 0))
          @message = "Your request was too big."
          @max_message_length_bytes = 0
          return 400, hs, builder(:max_message_length_exceeded)
        end

        # validate copy source.
        unless env["HTTP_X_AMZ_COPY_SOURCE"] =~ %r{^/(.*?)/(.+)$}
          @message = "Copy Source must mention the source bucket and key: sourcebucket/sourcekey"
          @argument_name = "x-amz-copy-source"
          return 400, hs, builder(:invalid_argument)
        else
          source_bucket = env["HTTP_X_AMZ_COPY_SOURCE"].split("/", 3)[1]
          source_key    = env["HTTP_X_AMZ_COPY_SOURCE"].split("/", 3)[2]
        end

        # validate source and destination.
        if source_bucket == @bucket and source_key == key
          if env["HTTP_X_AMZ_METADATA_DIRECTIVE"] and env["HTTP_X_AMZ_METADATA_DIRECTIVE"] == "REPLACE"
            @message = "Access Denied"
            return 403, hs, builder(:access_denied)
          end
          @message = "The Source and Destination may not be the same when the MetadataDirective is Copy and storage class unspecified"
          return 400, hs, builder(:invalid_request)
        end

        # check source bucket name.
        unless (source_basket_type = (S3CONFIG["buckets"][source_bucket] || {})["basket_type"])
          @bucket = source_bucket
          return 404, hs, builder(:no_such_bucket)
        end

        # get basket from database.
        unless (source_obj = S3Object.active.find_by_basket_type_and_path(source_basket_type, source_key))
          @key = source_key
          return 404, hs, builder(:no_such_key)
        end

        source_last_modified = Time.parse(source_obj.last_modified)

        # get file from castoro.
        unless (source_file = Adapter.get_basket_file(source_obj.to_basket))
          @key = source_key
          return 404, hs, builder(:no_such_key)
        end

        modified_since   = Time.httpdate(env["HTTP_X_AMZ_COPY_SOURCE_IF_MODIFIED_SINCE"]) rescue nil
        unmodified_since = Time.httpdate(env["HTTP_X_AMZ_COPY_SOURCE_IF_UNMODIFIED_SINCE"]) rescue nil

        # check x_amz_copy_source_if_unmodified_since.
        if unmodified_since and unmodified_since < source_last_modified
          @condition = 'x-amz-copy-source-If-Unmodified-Since'
          return 412, hs, builder(:precondition_failed)
        end

        # check x_amz_copy_source_if_match.
        if env["HTTP_X_AMZ_COPY_SOURCE_IF_MATCH"] and source_obj.etag != env["HTTP_X_AMZ_COPY_SOURCE_IF_MATCH"].gsub("\"", "")
          @condition = 'x-amz-copy-source-If-Match'
          return 412, hs, builder(:precondition_failed)
        end

        # check x_amz_copy_source_if_none_match and x_amz_copy_source_if_modified_since.
        if env["HTTP_X_AMZ_COPY_SOURCE_IF_NONE_MATCH"] and modified_since
          if source_obj.etag == env["HTTP_X_AMZ_COPY_SOURCE_IF_NONE_MATCH"].gsub("\"", "") and source_last_modified <= modified_since
            @condition = 'x-amz-copy-source-If-Modified-Since'
            return 412, hs, builder(:precondition_failed)
          end
        elsif env["HTTP_X_AMZ_COPY_SOURCE_IF_NONE_MATCH"] and source_obj.etag == env["HTTP_X_AMZ_COPY_SOURCE_IF_NONE_MATCH"].gsub("\"", "")
          @condition = 'x-amz-copy-source-If-None-Match'
          return 412, hs, builder(:precondition_failed)
        elsif modified_since and source_last_modified <= modified_since
          @condition = 'x-amz-copy-source-If-Modified-Since'
          return 412, hs, builder(:precondition_failed)
        end

        # get source file.
        content = StringIO.new(File.open(source_file, "rb") { |f| f.read })

        # copy metadata from database of basket.
        unless env["HTTP_X_AMZ_METADATA_DIRECTIVE"] == "REPLACE"
          # x-amz-metadata-directive = COPY(default).
          content_type = source_obj.content_type
          expires = source_obj.expires || nil
          cache_control = source_obj.cache_control || nil
          content_encoding = source_obj.content_encoding || nil
          content_disposition = source_obj.content_disposition || nil
        end

        # get and create basket from database.
        if (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
          obj.basket_rev         += 1
          obj.etag                = source_obj.etag
          obj.size                = source_obj.size
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
            o.etag                = source_obj.etag
            o.size                = source_obj.size
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
        Adapter.put_basket_file(basket, content)

        @last_modified = last_modified
        @etag = source_obj.etag
        return 200, hs, builder(:copy_object_result)
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

    # PUT Object and PUT Object - Copy
    put %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key

      if env.key?("HTTP_X_AMZ_COPY_SOURCE")
        return copy_object bucket, key
      else
        return put_object bucket, key
      end
    end

  end
end

