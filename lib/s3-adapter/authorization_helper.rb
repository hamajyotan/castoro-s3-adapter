
require 'openssl'

module S3Adapter
  module AuthorizationHelper

    @@users = {
      'A2E9126B863648840AB1' => {
        :display_name => 'test_user',
        :secret => 'cbUUiHIkVY2jv2wwI1zcEQqLMKNmfN6BcIrphgq9',
      },
    }

    def authorization method, bucket, object, headers = {}
      return nil unless headers['Authorization'] =~ /^AWS (\w+):(.+)$/
      access_key_id, secret = $1, $2
      return nil unless (user = User.find_by_access_key_id(access_key_id))

      signature = aws_signature user.secret,
                                method,
                                File.join("/", bucket, object),
                                headers

      (signature == secret) ? user : nil
    end

    def anonymous_user? headers = {}
      ! headers['Authorization']
    end

    def aws_signature secret, method, path, headers = {}
      hs = headers.inject({}) { |h,(k,v)|
        h[k.to_s.downcase] = v.to_s
        h
      }

      msg = [
        method.upcase,
        hs['content-md5']  || '',
        hs['content-type'] || '',
        hs['x-amz-date']   || hs['date'] || '',
      ]

      amz_headers = hs.map { |k, v|
        key = k.strip.gsub(/\s+/u, ' ')
        val = v.strip.gsub(/\s+/u, ' ')
        (key.index('x-amz-') == 0) ? [key, val] : nil
      }.compact
      amz_headers.sort { |x, y| x[0] <=> y[0] }.each { |k,v| msg << "#{k}:#{v}" }

      msg << path

      hmac = OpenSSL::HMAC.new(secret, OpenSSL::Digest::SHA1.new)
      [hmac.update(msg.join("\n")).digest].pack("m").gsub(/\s/u, '')
    end

  end
end

