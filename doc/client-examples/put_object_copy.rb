#!/usr/bin/env ruby

require File.expand_path('../common', __FILE__)
options = $config.dup


command_line { |opt|
  opt.banner = "\nUsage:  #{File.basename($0)}  [options]  OBJECT  COPY_SOURCE"

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

  opt.on('--head-content-type [HEAD]', 'PUT Object Copy header Content-Type') { |v|
    options['headers']['Content-Type'] = v
  }
  opt.on('--head-x-amz-acl [HEAD]', 'PUT Object Copy header x-amz-acl') { |v|
    options['headers']['x-amz-acl'] = v
  }
  opt.on('--head-x-amz-metadata-directive [HEAD]', 'PUT Object Copy header x-amz-metadata-directive') { |v|
    options['headers']['x-amz-metadata-directive'] = v
  }
  opt.on('--head-x-amz-copy-source-if-match [HEAD]', 'PUT Object Copy header x-amz-copy-source-if-match') { |v|
    options['headers']['x-amz-copy-source-if-match'] = v
  }
  opt.on('--head-x-amz-copy-source-if-none-match [HEAD]', 'PUT Object Copy header x-amz-copy-source-if-none-match') { |v|
    options['headers']['x-amz-copy-source-if-none-match'] = v
  }
  opt.on('--head-x-amz-copy-source-if-unmodified-since [HEAD]', 'PUT Object Copy header x-amz-copy-source-if-unmodified-since') { |v|
    options['headers']['x-amz-copy-source-if-unmodified-since'] = v
  }
  opt.on('--head-x-amz-copy-source-if-modified-since [HEAD]', 'PUT Object Copy header x-amz-copy-source-if-modified-since') { |v|
    options['headers']['x-amz-copy-source-if-modified-since'] = v
  }
  opt.on('--head-x-amz-storage-class [HEAD]', 'PUT Object Copy header x-amz-storage-class') { |v|
    options['headers']['x-amz-storage-class'] = v
  }

  begin
    opt.parse! ARGV
    options['object'], options['source'], = ARGV
    raise if [options['object'], options['source']].any? { |a| a.nil? }
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

  uri = "/#{options['bucket']}/#{options['object']}"
  unless options['parameters'].empty?
    uri << '?' << options['parameters'].map { |k,v| "#{k}=#{v}" }.join('&')
  end
  headers = options['headers']
  headers['x-amz-copy-source'] = options['source']
  if options['auth'] and not options['anonymous']
    headers['Authorization'] = authorization_header 'PUT', uri, headers, options['auth']
  end
  data = ""

  res = http.put(uri, data, headers)

  puts res.code
  res.each { |k,v| puts "\t#{k}: #{v}" }
  $stdout.write res.body
  puts
}

