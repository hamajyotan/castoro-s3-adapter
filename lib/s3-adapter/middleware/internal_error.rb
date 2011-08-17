
require 'builder'

module S3Adapter::Middleware
  class InternalError

    def initialize app
      @app = app
    end

    def call env
      code, headers, body = @app.call(env)
    rescue StandardError, LoadError, SyntaxError => e
      res = error_response e
      [
        500,
        {
          "Content-Type" => "application/xml",
          "Content-Length" => res.size.to_s,
        },
        [ res ]
      ]
    end

    private

    def error_response error
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      xml.Error do
        xml.Code "InternalError"
        xml.Message error.message
        xml.RequestId
        xml.HostId
      end
    end

  end
end

