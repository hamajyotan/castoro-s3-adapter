
require 'erb'
require 'yaml'

$config = YAML.load(ERB.new(IO.read(File.expand_path('../config.yml', __FILE__))).result)

module Kernel
  def puts *args
    $stderr.puts *args
  end
end

require 'optparse'

def command_line
  OptionParser.new { |opt|
    opt.summary_width = 48
    yield opt
  }
end

require 'openssl'

def authorization_header method, uri, headers, auth
  access_key_id, secret_access_key = auth['access-key-id'], auth['secret-access-key']

  path, query_string = uri.split('?', 2)
  params = query_string.to_s.split('&').inject({}) { |h,q|
             k,v = q.split('=', 2)
             h[k] = v
             h
           }
  signature_params = [
                       'response-cache-control',
                       'response-content-disposition',
                       'response-content-encoding',
                       'response-content-language',
                       'response-content-type',
                       'response-expires',
                     ].sort.inject([]) { |p,k|
                       p << "#{k}=#{params[k]}" if params.include?(k)
                       p
                     }.join('&')
  signature_path = "#{path}#{signature_params.empty? ? "" : "?#{signature_params}"}"

  hs = headers.inject({}) { |h,(k,v)| h[k.downcase] = v; h }

  msg = [
    method.upcase,
    hs['content-md5'].to_s,
    hs['content-type'].to_s,
    (hs['x-amz-date'] || hs['date']).to_s,
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

  msg << signature_path

  hmac = OpenSSL::HMAC.new(secret_access_key, OpenSSL::Digest::SHA1.new)
  signature = [hmac.update(msg.join("\n")).digest].pack("m").gsub(/\s/u, '')

  "AWS #{access_key_id}:#{signature}"
end

require 'net/http'

class Net::HTTPGenericRequest
  def supply_default_content_type; end
end
