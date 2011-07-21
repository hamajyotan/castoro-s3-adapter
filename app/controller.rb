
module S3Adapter
  class Controller < Sinatra::Base

    set :environment, ENV['RACK_ENV']
    set :logging, true
    set :static, false
    set :views, File.dirname(__FILE__) + "/views"
    set :lock, true

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
          :last_modified => o.last_modified.iso8601,
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
      modified_since   = Time.httpdate(env["HTTP_IF_MODIFIED_SINCE"]) rescue nil
      unmodified_since = Time.httpdate(env["HTTP_IF_UNMODIFIED_SINCE"]) rescue nil

      # check bucket name.
      unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
        status 404
        return nil 
      end

      # get basket from database.
      unless (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
        status 404
        return nil
      end

      # check if_unmodified_since
      if unmodified_since and unmodified_since < obj.last_modified
        status 412
        return nil
      end

      # check if_match
      if env["HTTP_IF_MATCH"] and obj.etag != env["HTTP_IF_MATCH"].gsub("\"", "")
        status 412
        return nil
      end

      # check if_none_match
      if env["HTTP_IF_NONE_MATCH"] and obj.etag == env["HTTP_IF_NONE_MATCH"].gsub("\"", "")
        status 304
        headers to_response_headers(obj)
        return nil
      end
      
      # TODO: implement the behavior of the range header.
      # check range
      #if env["HTTP_RANGE"] 
      #end

      # check if_modified_since
      if modified_since and obj.last_modified <= modified_since
        status 304
        headers to_response_headers(obj)
        return nil
      end
      
      status 200
      headers to_response_headers(obj)
      nil
    end

    # GET Object
    get %r{^/(.*?)/(.+)$} do |bucket, key|
      @bucket, @key = bucket, key

      # check bucket name.
      unless (basket_type = (S3CONFIG["buckets"][@bucket] || {})["basket_type"])
        status 404
        return builder(:no_such_bucket)
      end

      # get basket from database.
      unless (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
        status 404
        return builder(:no_such_key)
      end
      basket = obj.to_basket

      # get file from castoro.
      unless (file = Adapter.get_basket_file(basket))
        status 404
        return builder(:no_such_key)
      end

      headers "last-modified" => obj.last_modified.httpdate,
              "etag" => obj.etag
      body File.open(file, "rb") { |f| f.read }
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
      size = request.body.size
     
      # get and create basket from database.
      if (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
        obj.basket_rev += 1
        obj.last_modified = last_modified
        obj.etag = etag
        obj.size = size
      else
        obj = S3Object.create { |o|
          o.basket_type = basket_type
          o.path = key
          o.basket_id = o.next_basket_id(basket_type)
          o.basket_rev = 1
          o.last_modified = last_modified
          o.etag = etag
          o.size = size
        }
      end
      obj.save
      basket = obj.to_basket

      # create basket to castoro.
      size = 0
      Adapter.put_basket_file(basket, body) { |readed_size|
        size += readed_size
      }

      status 200
      nil
    end

    private

    def to_response_headers metadata
      {
        "last-modified" => metadata.last_modified.httpdate,
        "etag" => metadata.etag
      }
    end

  end
end

