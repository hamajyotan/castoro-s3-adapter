
module S3Adapter::Middleware
  # When the same key is generated in the GET parameter,
  # only the value that appears previously is made effective.
  class UniqueGetParameter

    def initialize app
      @app = app
    end

    def call env
      if env['REQUEST_METHOD'] == 'GET'
        env['QUERY_STRING'] = env['QUERY_STRING'].split('&').inject({}) { |h,q|
          k, v = q.split('=', 2)
          h[k] = v unless h.include?(k)
          h
        }.map { |k,v| "#{k}=#{v}" }.join('&') unless env['QUERY_STRING'].empty?
      end
      code, headers, body = @app.call(env)
    end

  end
end

