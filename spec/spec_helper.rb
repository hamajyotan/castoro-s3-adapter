
ENV['RACK_ENV'] = 'test'

# application.
require File.expand_path('../../config/application', __FILE__)

require 'rspec'
require 'rack/test'

# redifined Rack::Test:: Methods
module Rack
  class MockRequest
    # Return the Rack environment used for a request to +uri+.
    # Modified don't override Content-Length the length of body.
    def self.env_for(uri="", opts={})
      uri = URI(uri)
      uri.path = "/#{uri.path}" unless uri.path[0] == ?/

      env = DEFAULT_ENV.dup

      env["REQUEST_METHOD"] = opts[:method] ? opts[:method].to_s.upcase : "GET"
      env["SERVER_NAME"] = uri.host || "example.org"
      env["SERVER_PORT"] = uri.port ? uri.port.to_s : "80"
      env["QUERY_STRING"] = uri.query.to_s
      env["PATH_INFO"] = (!uri.path || uri.path.empty?) ? "/" : uri.path
      env["rack.url_scheme"] = uri.scheme || "http"
      env["HTTPS"] = env["rack.url_scheme"] == "https" ? "on" : "off"

      env["SCRIPT_NAME"] = opts[:script_name] || ""

      if opts[:fatal]
        env["rack.errors"] = FatalWarner.new
      else
        env["rack.errors"] = StringIO.new
      end

      if params = opts[:params]
        if env["REQUEST_METHOD"] == "GET"
          params = Utils.parse_nested_query(params) if params.is_a?(String)
          params.update(Utils.parse_nested_query(env["QUERY_STRING"]))
          env["QUERY_STRING"] = Utils.build_nested_query(params)
        elsif !opts.has_key?(:input)
          opts["CONTENT_TYPE"] = "application/x-www-form-urlencoded"
          if params.is_a?(Hash)
            if data = Utils::Multipart.build_multipart(params)
              opts[:input] = data
              opts["CONTENT_LENGTH"] ||= data.length.to_s
              opts["CONTENT_TYPE"] = "multipart/form-data; boundary=#{Utils::Multipart::MULTIPART_BOUNDARY}"
            else
              opts[:input] = Utils.build_nested_query(params)
            end
          else
            opts[:input] = params
          end
        end
      end

      empty_str = ""
      empty_str.force_encoding("ASCII-8BIT") if empty_str.respond_to? :force_encoding
      opts[:input] ||= empty_str
      if String === opts[:input]
        rack_input = StringIO.new(opts[:input])
      else
        rack_input = opts[:input]
      end

      rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)
      env['rack.input'] = rack_input

      opts.each { |field, value|
        env[field] = value  if String === field
      }

      env
    end
  end

  module Test
    class Session
      # Added copy QUERY_STRING
      def get(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "GET", :params => params))
        env["QUERY_STRING"] = URI.parse(uri).query.to_s
        process_request(uri, env, &block)
      end

      private

      # Modified don't specified default Content-Type
      def env_for(path, env)
        uri = URI.parse(path)
        uri.path = "/#{uri.path}" unless uri.path[0] == ?/
        uri.host ||= @default_host

        env = default_env.merge(env)

        env["HTTP_HOST"] ||= [uri.host, uri.port].compact.join(":")

        env.update("HTTPS" => "on") if URI::HTTPS === uri
        env["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest" if env[:xhr]

        # TODO: Remove this after Rack 1.1 has been released.
        # Stringifying and upcasing methods has be commit upstream
        env["REQUEST_METHOD"] ||= env[:method] ? env[:method].to_s.upcase : "GET"

        if env["REQUEST_METHOD"] == "GET"
          params = env[:params] || {}
          params = parse_nested_query(params) if params.is_a?(String)
          params.update(parse_nested_query(uri.query))
          uri.query = build_nested_query(params)
        elsif !env.has_key?(:input)
          if env[:params].is_a?(Hash)
            if data = build_multipart(env[:params])
              env[:input] = data
              env["CONTENT_LENGTH"] ||= data.length.to_s
              env["CONTENT_TYPE"] = "multipart/form-data; boundary=#{MULTIPART_BOUNDARY}"
            else
              env[:input] = params_to_string(env[:params])
            end
          else
            env[:input] = env[:params]
          end
        end

        env.delete(:params)

        if env.has_key?(:cookie)
          set_cookie(env.delete(:cookie), uri)
        end

        Rack::MockRequest.env_for(uri.to_s, env)
      end
    end
  end
end

def signature_path path, query
  path << "?acl" if query.include?("acl")
  params = [].tap { |p|
    [
      'response-cache-control',
      'response-content-disposition',
      'response-content-encoding',
      'response-content-language',
      'response-content-type',
      'response-expires',
    ].sort.each { |k|
      p << "#{k}=#{query[k]}" if query.include?(k)
    }
  }

  "#{path}#{params.empty? ? '' : '?'}#{params.join('&')}"
end

def aws_signature secret, method, path, headers = {}
  query = {}
  key = path.split("?", 2)[0]
  req_params = path.split("?", 2)[1]
  if req_params
    req_params.split("&").each { |p|
      query["#{p.split("=", 2)[0]}"] = p.split("=", 2)[1] unless query["#{p.split("=", 2)[0]}"]
    }
  end
  path = signature_path key, query
  hs = {}.tap { |h|
    headers.select { |k,v| k.index('HTTP_') == 0 }.each { |k,v|
      h[k['HTTP_'.size, k.size].downcase.tr('_', '-')] = v.to_s
    }
  }

  msg = [
    method.upcase,
    hs['content-md5'].to_s,
    headers['CONTENT_TYPE'].to_s,
    hs['x-amz-date'] ? '' : hs['date'].to_s,
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

def app
  S3Adapter::Controller
end

ActiveRecord::Base.logger.level = Logger::INFO

def bucket_to_basket_type bucket
  S3CONFIG['buckets'][bucket]['basket_type']
end

def find_by_bucket_and_path bucket, path
  type = bucket_to_basket_type(bucket)
  obj = S3Object.find_by_basket_type_and_path(type, path) rescue nil
  yield obj if obj
end

def find_file_by_bucket_and_path bucket, path
  type = bucket_to_basket_type(bucket)
  obj = S3Object.find_by_basket_type_and_path(type, path)
  id, rev = obj.id, obj.basket_rev

  ret = Castoro::Client.new(nil).get("#{id}.#{type}.#{rev}".to_basket)
  host, path = ret.first
  path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
  File.open(path, 'r') { |f| yield(f) }
end
