
require 'openssl'

module S3Adapter::Middleware
  class Authorization

    def initialize app
      @app = app
    end

    def call env
      env['s3adapter.authorization'] = auth(env)
      @app.call env
    end

    private

    def auth env
      authorization = env['HTTP_AUTHORIZATION'].to_s
      return nil unless authorization =~ /^AWS (\w+):(.+)$/
      access_key_id, secret = $1, $2
      user = User.find_by_access_key_id(access_key_id) rescue nil
      return nil unless user

      if aws_signature(user.secret_access_key.to_s, env) == secret
        {
          'access_key_id' => access_key_id.to_s,
          'display_name' => user.display_name.to_s,
        }
      end
    end

    def signature_path env
      req = Rack::Request.new(env)
      params = [].tap { |p|
        [
          'response-cache-control',
          'response-content-disposition',
          'response-content-encoding',
          'response-content-language',
          'response-content-type',
          'response-expires',
        ].sort.each { |k|
          p << "#{k}=#{req.GET[k]}" if req.GET.include?(k)
        }
      }

      "#{req.path_info}#{params.empty? ? '' : '?'}#{params.join('&')}"
    end

    def aws_signature secret, env
      path = signature_path(env)
      hs = {}.tap { |h|
        env.select { |k,v| k.index('HTTP_') == 0 }.each { |k,v|
          h[k['HTTP_'.size, k.size].downcase.tr('_', '-')] = v.to_s
        }
      }

      msg = [ 
        env['REQUEST_METHOD'].upcase,
        hs['content-md5']   || '', 
        env['CONTENT_TYPE'] || '',
        hs['x-amz-date']    || hs['date'] || '', 
      ]   

      hs.map { |k, v|
        key = k.strip.gsub(/\s+/u, ' ')
        val = v.strip.gsub(/\s+/u, ' ')
        (key.index('x-amz-') == 0) ? [key, val] : nil 
      }.compact.sort { |x, y|
        x[0] <=> y[0]
      }.each { |k,v|
        msg << "#{k}:#{v}"
      }

      msg << path

      hmac = OpenSSL::HMAC.new(secret, OpenSSL::Digest::SHA1.new)
      [hmac.update(msg.join("\n")).digest].pack("m").gsub(/\s/u, '') 
    end 
  end
end

