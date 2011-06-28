
require "rubygems"

module Castoro #:nodoc:
  module S3Adapter #:nodoc:
    autoload :Adaptable , "castoro-s3-adapter/adaptable"
    autoload :Console   , "castoro-s3-adapter/console"
    autoload :Dispatcher, "castoro-s3-adapter/dispatcher"
    autoload :HttpServer, "castoro-s3-adapter/http_server"
    autoload :Service   , "castoro-s3-adapter/service"
    autoload :Version   , "castoro-s3-adapter/version"
  end
end

