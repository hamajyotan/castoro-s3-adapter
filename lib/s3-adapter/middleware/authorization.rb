
require 'openssl'

module S3Adapter::Middleware
  class Authorization

    def initialize app
      @app = app
    end

    def call env
      if authorization = env['HTTP_AUTHORIZATION']
        # validate Authorization header type.
        unless env['HTTP_AUTHORIZATION'].to_s =~ /^AWS /
          @message = "Authorization header is invalid -- one and only one ' ' (space) required"
          return response(400) { authorization_header(authorization) }
        end

        # validate format to Authorization header.
        authorization =~ /^AWS (.+)/
        tokens = $1.split(':')
        access_key_id = tokens.shift
        signature = tokens.shift
        if tokens.any? { |t| !t.empty? }
          @message = "AWS authorization header is invalid.  Expected AwsAccessKeyId:signature"
          return response(400) { authorization_header(authorization) }
        end

        # validate access_key_id.
        user = User.find_by_access_key_id(access_key_id) rescue nil
        return response(403) { invalid_access_key_id(access_key_id) } unless user

        # validate signature.
        unless aws_signature(user.secret_access_key.to_s, env) == signature
          return response(403) { signature_does_not_match(authorization) }
        end

        # validate date or x-amz-date header.
        return response(403) { invalid_date_header } unless request_time = env["HTTP_X_AMZ_DATE"] || env["HTTP_DATE"]
        system_time  = S3Adapter::DependencyInjector.time_now.utc
        request_time_utc = Time.parse(request_time).utc rescue (return response(403) { invalid_date_header })

        # validate time-stamp within 15 minutes.
        if request_time_utc >= system_time
          time_lag = request_time_utc - system_time
        elsif request_time_utc < system_time
          time_lag = system_time - request_time_utc
        end
        return response(403) { request_time_too_skewed(system_time, request_time) } if time_lag > 900

        env['s3adapter.authorization'] = {
          'access_key_id' => access_key_id.to_s,
          'display_name' => user.display_name.to_s,
        }
      end

      @app.call env
    end

    private

    def signature_path env
      req = Rack::Request.new(env)
      params = [].tap { |p|
        p << 'acl' if req.GET.include?('acl')
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
        hs['content-md5'].to_s,
        env['CONTENT_TYPE'].to_s,
        hs['x-amz-date'] ? '' : (hs['date'].to_s),
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
      @string_to_sign = msg

      hmac = OpenSSL::HMAC.new(secret, OpenSSL::Digest::SHA1.new)
      [hmac.update(msg.join("\n")).digest].pack("m").gsub(/\s/u, '')
    end

    def response code
      [
        code,
        { 'Content-Type' => 'application/xml;charset=utf-8' },
        [ yield ],
      ]
    end

    def invalid_date_header
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      xml.Error do
        xml.Code "AccessDenied"
        xml.Message "AWS authentication requires a valid Date or x-amz-date header"
        xml.RequestId
        xml.HostId
      end
    end

    def request_time_too_skewed system_time, request_time
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      xml.Error do
        xml.Code "RequestTimeTooSkewed"
        xml.Message "The difference between the request time and the current time is too large."
        xml.MaxAllowedSkewMilliseconds 900000
        xml.RequestId
        xml.HostId
        xml.RequestTime request_time
        xml.ServerTime system_time.utc.iso8601
      end
    end

    def authorization_header authorization
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      xml.Error do
        xml.Code "InvalidArgument"
        xml.Message @message
        xml.ArgumentValue authorization
        xml.ArgumentName "Authorization"
        xml.RequestId
        xml.HostId
      end
    end

    def invalid_access_key_id access_key_id
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      xml.Error do
        xml.Code "InvalidAccessKeyId"
        xml.Message "The AWS Access Key Id you provided does not exist in our records."
        xml.RequestId
        xml.HostId
        xml.AWSAccessKeyId access_key_id
      end
    end

    def signature_does_not_match authorization
      authorization.to_s =~ /^AWS (\w+):(.+)$/
      access_key_id, signature_provided = $1, $2
      sign = string_to_sign_bytes(@string_to_sign)
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      xml.Error do
        xml.Code "SignatureDoesNotMatch"
        xml.Message "The request signature we calculated does not match the signature you provided. Check your key and signing method."
        xml.StringToSignBytes sign
        xml.RequestId
        xml.HostId
        xml.SignatureProvided signature_provided
        xml.StringToSign @string_to_sign.join("\n")
        xml.AWSAccessKeyId access_key_id
      end
    end

    def string_to_sign_bytes sign
      sign.join("\n").each_byte.map { |b|
        "%02x" % b
      }.join(' ')
    end

  end

end

