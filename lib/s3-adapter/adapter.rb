
module S3Adapter
  module Adapter
  
    BASE = "/data"
    S3ADAPTER_FILE = "original".freeze
  
    def init
      c = (S3CONFIG["castoro-client"] || {})
      if c.to_s == 'mock'
        require 's3-adapter/mock/castoro-client'
      else
        c['logger'] = Logger.new(STDOUT)
      end
      @@client = Castoro::Client.new c
      @@client.open
    end
    module_function :init
  
    def get_basket_file basket
      res = @@client.get basket rescue nil
      return nil unless res
  
      res.each { |k, v|
        fullpath = File.join BASE, k, v, S3ADAPTER_FILE
        return fullpath if File.file?(fullpath)
      }
      nil
    end
    module_function :get_basket_file
  
    def delete_basket_file basket
      @@client.delete basket rescue nil
    end
    module_function :delete_basket_file
  
    def put_basket_file basket, io, size
      io.rewind
      @@client.create(basket, "class" => :original) { |host, path|
        fullpath = File.join BASE, host, path, S3ADAPTER_FILE
        File.open(fullpath, "wb") { |f| f.write(io.read(size)) }
      }
    end
    module_function :put_basket_file

  end
end

