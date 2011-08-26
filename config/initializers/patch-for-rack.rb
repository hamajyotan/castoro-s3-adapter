
require 'rubygems'
require 'rack'

module Rack
  # The delimiter of the request parameter is changed only to &. 
  class Request
    def parse_query(qs)
      Utils.parse_nested_query(qs, '&')
    end
  end

  # When zero is given to Content-Length by Rack handler for Webrick, it is disregarded.
  # It corresponds to this.
  module Handler
    class WEBrick
      alias_method :service_original, :service
      
      def service(req, res)
        class << req
          alias_method :meta_vars_original, :meta_vars
          def meta_vars
            env = meta_vars_original
            if env['CONTENT_LENGTH'].nil? and self['Content-Length'] =~ /^0+$/
              env['CONTENT_LENGTH'] = self['Content-Length']
            end
            env
          end
        end
        service_original(req, res)
      end
    end
  end
end

