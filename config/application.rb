
require File.expand_path('../../config/boot', __FILE__)

# castoro-client init.
require "s3-adapter/adapter"
S3Adapter::Adapter.init

