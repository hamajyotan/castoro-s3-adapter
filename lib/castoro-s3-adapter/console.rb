
require "castoro-s3-adapter"

require "monitor"
require "drb/drb"

module Castoro::S3Adapter #:nodoc:

  class Console

    ALLOW_OPTIONS = [
      :console_allow_host,
      :console_port,
    ].freeze

    ##
    # Initialize.
    #
    # === Args
    #
    # +logger+:: 
    #   the logger.
    # +options+::
    #   console options.
    #
    def initialize logger, options = {}
      @logger = logger
      options.reject { |k,v| !(ALLOW_OPTIONS.include? k.to_sym) }.each { |k,v|
        instance_variable_set "@#{k}", v
      }
      @uri = "druby://#{@console_allow_host}:#{@console_port}".freeze

      @locker = Monitor.new
    end

    ##
    # start console.
    #
    def start
      @locker.synchronize {
        raise S3AdapterError, "console already started." if alive?
        @logger.debug { "console uri - #{@uri}" }
        @drb = DRb::DRbServer.new @uri, self
      }
    end

    ##
    # stop console.
    #
    def stop
      @locker.synchronize {
        raise S3AdapterError, "console already stopped." unless alive?
        @drb.stop_service
        @drb = nil
      }
    end

    ##
    # return the state of alive or not alive.
    #
    def alive?
      @locker.synchronize {
        !! (@drb and @drb.alive?)
      }
    end

    attr_reader :uri

  end

end

