#!/usr/bin/env ruby

require File.expand_path('../common', __FILE__)
options = $config.dup


command_line { |opt|
  opt.banner = "\nUsage:  #{File.basename($0)}  [options]  ACL_FILE"

  opt.on('-a [ADDRESS]', '--address', "s3-adapter address (default: #{options['address']})") { |v|
    options['address'] = v
  }
  opt.on('-p [PORT]', '--port', "s3-adapter port (default: #{options['port']})") { |v|
    options['port'] = v
  }
  opt.on('-b [BUCKET]', '--bucket', "s3 bucketname (default: #{options['bucket']})") { |v|
    options['bucket'] = v
  }
  opt.on('-n', '--anonymous', "Anonymous user request") { |v|
    options['anonymous'] = v
  }

  begin
    opt.parse! ARGV
    options['file'], = ARGV
    raise if [options['file']].any? { |a| a.nil? }
  rescue
    puts opt.help
    exit 1
  end
}


require 'net/http'
http_class = if options['proxy']
               Net::HTTP::Proxy(options['proxy']['address'], options['proxy']['port'])
             else
               Net::HTTP
             end

http_class.start(options['address'], options['port']) { |http|

  uri = "/#{options['bucket']}?acl"
  unless options['parameters'].empty?
    uri << '?' << options['parameters'].map { |k,v| "#{k}=#{v}" }.join('&')
  end
  headers = options['headers']
  if options['auth'] and not options['anonymous']
    headers['Authorization'] = authorization_header 'PUT', uri, headers, options['auth']
  end
  data = File.open(options['file'], 'r') { |f| f.read }

  res = http.put(uri, data, headers)

  puts "\n[WARN]: s3-adapter has not supported PUT Bucket acl yet."
  puts res.code
  res.each { |k,v| puts "\t#{k}: #{v}" }
  $stdout.write res.body
  puts
}

