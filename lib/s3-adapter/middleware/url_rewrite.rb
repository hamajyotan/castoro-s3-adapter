
module S3Adapter::Middleware
  # When Bucket by the subdomain is specified, Rewrite does URL.
  #
  # Example (when domain is foo.bar.baz):
  #  http://bucket.foo.bar.baz -> http://foo.bar.baz/bucket
  class UrlRewrite

    def initialize app, domain
      @app = app
      @domain = domain
      @domain_regexp = @domain ? /^(\S+)\.#{Regexp.escape(@domain)}(:(\d+))?$/ : nil
      @rewrite_proc = @domain ? method(:rewrite) : Proc.new { |env| }
    end

    def call env
      @rewrite_proc.call(env)
      @app.call(env)
    end

    private

    def rewrite env
      if env['HTTP_HOST'].to_s =~ @domain_regexp
        bucket, port = $1, $3
        env['HTTP_HOST'] = "#{@domain}#{port ? ":#{port}" : nil}"
        env['PATH_INFO'] = "/#{bucket}#{env['PATH_INFO']}"
      end
    end

  end
end

