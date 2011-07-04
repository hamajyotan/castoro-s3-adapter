
require "castoro-s3-adapter"

require "sinatra/base"
require "builder"

module Castoro::S3Adapter #:nodoc:

  module Adaptable

    BASE = "/data"

    def get_basket basket
      res = @client.get basket rescue nil
      return nil unless res

      res.each { |k, v|
        fullpath = File.join BASE, k, v, "/"
        return fullpath if File.directory?(fullpath)
      }
      nil
    end

    def get_basket_file basket, file
      res = @client.get basket rescue nil
      return nil unless res

      res.each { |k, v|
        fullpath = File.join BASE, k, v, file
        return fullpath if File.file?(fullpath)
      }
      nil
    end
  end

end
