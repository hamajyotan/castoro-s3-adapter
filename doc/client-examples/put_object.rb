#!/usr/bin/env ruby

require File.expand_path('../common', __FILE__)
options = $config.dup


command_line { |opt|
  opt.banner = "\nUsage:  #{File.basename($0)}  [options]  OBJECT  FILE"

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

  opt.on('--head-cache-control [HEAD]', 'PUT Object header Cache-Control') { |v|
    options['headers']['Cache-Control'] = v
  }
  opt.on('--head-content-disposition [HEAD]', 'PUT Object header Content-Disposition') { |v|
    options['headers']['Content-Disposition'] = v
  }
  opt.on('--head-content-encoding [HEAD]', 'PUT Object header Content-Encoding') { |v|
    options['headers']['Content-Encoding'] = v
  }
  opt.on('--head-content-length [HEAD]', 'PUT Object header Content-Length') { |v|
    options['headers']['Content-Length'] = v
  }
  opt.on('--head-content-md5 [HEAD]', 'PUT Object header Content-MD5') { |v|
    options['headers']['Content-MD5'] = v
  }
  opt.on('--head-content-type [HEAD]', 'PUT Object header Content-Type') { |v|
    options['headers']['Content-Type'] = v
  }
  opt.on('--head-expect [HEAD]', 'PUT Object header Expect') { |v|
    options['headers']['Expect'] = v
  }
  opt.on('--head-expires [HEAD]', 'PUT Object header Expires') { |v|
    options['headers']['Expires'] = v
  }
  opt.on('--head-x-amz-acl [HEAD]', 'PUT Object header x-amz-acl') { |v|
    options['headers']['x-amz-acl'] = v
  }
  # TODO: implement metadata options.
  opt.on('--head-x-amz-storage-class [HEAD]', 'PUT Object header x-amz-storage-class') { |v|
    options['headers']['x-amz-storage-class'] = v
  }

  begin
    opt.parse! ARGV
    options['object'], options['file'], = ARGV
    raise if [options['object'], options['file']].any? { |a| a.nil? }
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
    headers['Authorization'] = authorization_header 'PUT', uri, headers, options['auth']
  end
  data = File.open(options['file'], 'r') { |f| f.read }

  res = http.put(uri, data, headers)

  puts res.code
  res.each { |k,v| puts "\t#{k}: #{v}" }
  $stdout.write res.body
  puts
}

