#!/usr/bin/env ruby

require File.expand_path('../common', __FILE__)
options = $config.dup


command_line { |opt|
  opt.banner = "\nUsage:  #{File.basename($0)}  [options]"

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

  opt.on('--param-delimiter [PARAM]', "GET Bucket parameter delimiter") { |v|
    options['parameters']['delimiter'] = v
  }
  opt.on('--param-marker [PARAM]', "GET Bucket parameter marker") { |v|
    options['parameters']['marker'] = v
  }
  opt.on('--param-max-keys [PARAM]', "GET Bucket parameter max-keys") { |v|
    options['parameters']['max_keys'] = v
  }
  opt.on('--param-prefix [PARAM]', "GET Bucket parameter prefix") { |v|
    options['parameters']['prefix'] = v
  }

  begin
    opt.parse! ARGV
  rescue
    puts opt.help
    exit 1
  end
}


require 'net/http'

Net::HTTP.start(options['address'], options['port']) { |http|

  uri = "/#{options['bucket']}/"
  unless options['parameters'].empty?
    uri << '?' << options['parameters'].map { |k,v| "#{k}=#{v}" }.join('&')
  end
  headers = options['headers']
  if options['auth'] and not options['anonymous']
    headers['Authorization'] = authorization_header 'GET', uri, headers, options['auth']
  end

  res = http.get(uri, headers)

  puts res.code
  res.each { |k,v| puts "\t#{k}: #{v}" }
  $stdout.write res.body
  puts
}

