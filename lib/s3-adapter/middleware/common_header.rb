
require 'time'

module S3Adapter::Middleware
  class CommonHeader
    def initialize app
      @app = app
    end
    def call env
      code, headers, body = @app.call(env)
      headers['server'] = 'AmazonS3'
      headers['date'] = Time.now.utc.httpdate
      [code, headers, body]
    end
  end
end

