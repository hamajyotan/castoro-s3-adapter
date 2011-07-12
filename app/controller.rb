
module S3Adapter
  class Controller < Sinatra::Base

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

      builder(:list_bucket_result)
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
      unless (file = Adapter::get_basket_file(basket))
        status 404
        return builder(:no_such_key)
      end

      st = File.stat(file)
      headers "last-modified" => st.mtime.httpdate,
              "etag" => sprintf("%x-%x-%x", st.ino, st.size, st.mtime)
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
      unless (file = Adapter::get_basket_file(basket))
        status 204
        return nil
      end

      # delete basket and database.
      Adapter::delete_basket_file basket
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

      # get and create basket from database.
      if (obj = S3Object.find_by_basket_type_and_path(basket_type, key))
        obj.basket_rev += 1
      else
        obj = S3Object.create { |o|
          o.basket_type = basket_type
          o.path = key
          o.basket_id = o.next_basket_id(basket_type)
          o.basket_rev = 1
        }
      end
      obj.save
      basket = obj.to_basket

      # create basket to castoro.
      Adapter::put_basket_file(basket, request.body)

      status 200
      nil
    end

  end
end

