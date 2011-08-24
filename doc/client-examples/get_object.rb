#!/usr/bin/env ruby

require File.expand_path('../common', __FILE__)
options = $config.dup


command_line { |opt|
  opt.banner = "\nUsage:  #{File.basename($0)}  [options]  OBJECT"

  opt.on('-a [ADDRESS]', '--address', "s3-adapter address (default: #{options['address']})") { |v|
    options['address'] = v
  }
  opt.on('-p [PORT]', '--port', "s3-adapter port (default: #{options['port']})") { |v|
    options['port'] = v
  }
  opt.on('-b [BUCKET]', '--bucket', "s3 bucketname (default: #{options['bucket']})") { |v|
    options['bucket'] = v
  }

  opt.on('--param-response-content-type [PARAM]', "GET Object parameter response-content-type") { |v|
    options['parameters']['response-content-type'] = v
  }
  opt.on('--param-response-content-language [PARAM]', "GET Object parameter response-content-language") { |v|
    options['parameters']['response-content-language'] = v
  }
  opt.on('--param-response-expires [PARAM]', "GET Object parameter response-expires") { |v|
    options['parameters']['response-expires'] = v
  }
  opt.on('--param-response-cache-control [PARAM]', "GET Object parameter response-cache-control") { |v|
    options['parameters']['response-cache-control'] = v
  }
  opt.on('--param-response-content-disposition [PARAM]', "GET Object parameter response-content-disposition") { |v|
    options['parameters']['response-content-disposition'] = v
  }
  opt.on('--param-response-content-encoding [PARAM]', "GET Object parameter response-content-encoding") { |v|
    options['parameters']['response-content-encoding'] = v
  }

  opt.on('--head-range [HEAD]', 'GET Object header Range') { |v|
    options['headers']['Range'] = v
  }
  opt.on('--head-if-modified-since [HEAD]', 'GET Object header If-Modified-Since') { |v|
    options['headers']['If-Modified-Since'] = v
  }
  opt.on('--head-if-unmodified-since [HEAD]', 'GET Object header If-Unmodified-Since') { |v|
    options['headers']['If-Unmodified-Since'] = v
  }
  opt.on('--head-if-match [HEAD]', 'GET Object header If-Match') { |v|
    options['headers']['If-Match'] = v
  }
  opt.on('--head-if-none-match [HEAD]', 'GET Object header If-None-Match') { |v|
    options['headers']['If-None-Match'] = v
  }

  begin
    opt.parse! ARGV
    options['object'], = ARGV
    raise if [options['object']].any? { |a| a.nil? }
  rescue
    puts opt.help
    exit 1
  end
}


require 'net/http'

Net::HTTP.start(options['address'], options['port']) { |http|

  uri = "/#{options['bucket']}/#{options['object']}"
  unless options['parameters'].empty?
    uri << '?' << options['parameters'].map { |k,v| "#{k}=#{v}" }.join('&')
  end
  headers = options['headers']

  res = http.get(uri, headers)

  puts res.code
  res.each { |k,v| puts "\t#{k}: #{v}" }
  $stdout.write res.body
  puts
}

