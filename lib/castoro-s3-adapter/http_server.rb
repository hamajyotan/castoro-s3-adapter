
require "castoro-s3-adapter"

require "monitor"
require "rack"
require "rack/handler/webrick"

module Castoro::S3Adapter #:nodoc:

  class HttpServer

    ALLOW_OPTIONS = [ 
      :allow_host,
      :port,
    ].freeze

    # Initialize.
    #   
    # === Args
    #   
    # +logger+      :: The logger.
    # +dispatcher+  :: rack application instance.
    # +options+     :: terminal options.
    #   
    # Valid options for +options+ are:   
    #
    # +allow_host+  :: allow host address.
    # +port+        :: listen port number
    #                                             
    def initialize logger, dispatcher, options = {}
      @logger     = logger
      @dispatcher = dispatcher
      options.reject { |k,v| !(ALLOW_OPTIONS.include? k.to_sym) }.each { |k,v|
        instance_variable_set "@#{k}", v
      }
      @locker = Monitor.new
    end

    # Start http server.
    #
    def start
      @locker.synchronize {
        dispatcher = @dispatcher
        app = Rack::Builder.new { run dispatcher }

        @server = WEBrick::HTTPServer.new :logger => @logger,
                                          :DirectoryIndex => [],
                                          :DocumentRoot => nil,
                                          :DocumentRootOptions => { :FancyIndexing => false },
                                          :Port => @port,
                                          :BindAddress => @allow_host
        @server.mount "/", Rack::Handler::WEBrick, app
        @thread = Thread.fork { @server.start }
      }
    end

    # Stop http server.
    #
    def stop
      @locker.synchronize {
        @server.shutdown
        @server = nil
  
        @thread.join
        @thread = nil
      }
    end

    # Return the state of alive or not alive.
    #
    def alive?
      @locker.synchronize {
        !! (@server and @server.status == :Running and @thread and @thread.alive?)
      }
    end

  end
end

