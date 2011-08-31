
module S3Adapter
  autoload :Adapter, 's3-adapter/adapter'
  autoload :DependencyInjector, 's3-adapter/dependency_injector'

  module Middleware
    autoload :Authorization     , 's3-adapter/middleware/authorization'
    autoload :CommonHeader      , 's3-adapter/middleware/common_header'
    autoload :InternalError     , 's3-adapter/middleware/internal_error'
    autoload :UniqueGetParameter, 's3-adapter/middleware/unique_get_parameter'
    autoload :UrlRewrite        , 's3-adapter/middleware/url_rewrite'
  end
end

