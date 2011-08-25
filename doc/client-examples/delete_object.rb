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
  opt.on('-n', '--anonymous', "Anonymous user request") { |v|
    options['anonymous'] = v
  }

  opt.on('--head-x-amz-mfa [HEAD]', 'DELETE Object header x-amz-mfa') { |v|
    options['headers']['x-amz-mfa'] = v
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
  if options['auth'] and not options['anonymous']
    headers['Authorization'] = authorization_header 'DELETE', uri, headers, options['auth']
  end

  res = http.delete(uri, headers)

  puts res.code
  res.each { |k,v| puts "\t#{k}: #{v}" }
  $stdout.write res.body
  puts
}

