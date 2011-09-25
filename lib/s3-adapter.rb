
module S3Adapter
  autoload :Acl, 's3-adapter/acl'
  autoload :Adapter, 's3-adapter/adapter'
  autoload :Authenticator, 's3-adapter/authenticator'
  autoload :DependencyInjector, 's3-adapter/dependency_injector'
  autoload :FileStream, 's3-adapter/file_stream'

  module Helper
    autoload :AclHelper         , 's3-adapter/helper/acl_helper'
  end

  module Helper
    autoload :AclHelper         , 's3-adapter/helper/acl_helper'
  end

  module Middleware
    autoload :Authorization     , 's3-adapter/middleware/authorization'
    autoload :CommonHeader      , 's3-adapter/middleware/common_header'
    autoload :InternalError     , 's3-adapter/middleware/internal_error'
    autoload :UniqueGetParameter, 's3-adapter/middleware/unique_get_parameter'
    autoload :UrlRewrite        , 's3-adapter/middleware/url_rewrite'
  end
end

