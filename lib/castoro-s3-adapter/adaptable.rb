
require "castoro-s3-adapter"

require "sinatra/base"
require "builder"

module Castoro::S3Adapter #:nodoc:

  module Adaptable

    BASE = "/data"

    def get_files basket
      res = @client.get basket rescue nil
      return nil unless res

      # TODO: Choice does host that can be used.
      host, path = nil, nil
      res.each { |k,v| host, path = k, v }

      fullpath = File.join BASE, host, path
      Dir[File.join(fullpath, "*")].inject({}) { |h, k|
        h[k] = File.stat k
        h
      }
    end

    def get_file basket, file
      res = @client.get basket rescue nil
      return nil unless res

      # TODO: Choice does host that can be used.
      host, path = nil, nil
      res.each { |k,v| host, path = k, v }

      fullpath = File.join BASE, host, path, file
      return nil unless File.exist?(fullpath)

      fullpath
    end

  end

end
