
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'GET Bucket' do
  include Rack::Test::Methods

  before(:all) do
    S3Object.delete_all
    S3Object.new { |o|
      o.basket_type = 999
      o.path = "foo/bar/baz.txt"
      o.id = 1
      o.basket_rev = 1
      o.last_modified = "2011-07-21T19:14:36+09:00"
      o.etag = "ea703e7aa1efda0064eaa507d9e8ab7e"
      o.size = 4
      o.content_type = "application/octet-stream"
      o.save
    }
    S3Object.new { |o|
      o.basket_type = 999
      o.path = "hoge/fuga.jpg"
      o.id = 2
      o.basket_rev = 3
      o.last_modified = "2011-07-22T21:23:41+09:00"
      o.etag = "73feffa4b7f6bb68e44cf984c85f6e88"
      o.size = 3
      o.content_type = "image/jpeg"
      o.save
    }
    S3Object.new { |o|
      o.basket_type = 999
      o.path = "hoge/piyo.gif"
      o.id = 3
      o.basket_rev = 2
      o.last_modified = "2011-07-22T22:22:59+09:00"
      o.etag = "8059cabc22e766aea3c60ce67a82075e"
      o.size = 8
      o.content_type = "image/gif"
      o.save
    }
  end

  context 'given valid bucketname' do
    it 'should return object-list' do
      get '/castoro/'

      last_response.should be_ok
      xml = REXML::Document.new last_response.body
      xml.elements["ListBucketResult/Name"].text.should == "castoro"
      xml.elements["ListBucketResult/Prefix"].text.should == nil
      xml.elements["ListBucketResult/Marker"].text.should == nil
      xml.elements["ListBucketResult/MaxKeys"].text.should == "1000"
      xml.elements["ListBucketResult/IsTruncated"].text.should == "false"
      xml.elements["ListBucketResult/Contents[1]/Key"].text.should == "foo/bar/baz.txt"
      xml.elements["ListBucketResult/Contents[1]/LastModified"].text.should == "2011-07-21T19:14:36+09:00"
      xml.elements["ListBucketResult/Contents[1]/ETag"].text.should == "ea703e7aa1efda0064eaa507d9e8ab7e"
      xml.elements["ListBucketResult/Contents[1]/Size"].text.should == "4"
      xml.elements["ListBucketResult/Contents[1]/StorageClass"].text.should == "STANDARD"
      xml.elements["ListBucketResult/Contents[2]/Key"].text.should == "hoge/fuga.jpg"
      xml.elements["ListBucketResult/Contents[2]/LastModified"].text.should == "2011-07-22T21:23:41+09:00"
      xml.elements["ListBucketResult/Contents[2]/ETag"].text.should == "73feffa4b7f6bb68e44cf984c85f6e88"
      xml.elements["ListBucketResult/Contents[2]/Size"].text.should == "3"
      xml.elements["ListBucketResult/Contents[2]/StorageClass"].text.should == "STANDARD"
      xml.elements["ListBucketResult/Contents[3]/Key"].text.should == "hoge/piyo.gif"
      xml.elements["ListBucketResult/Contents[3]/LastModified"].text.should == "2011-07-22T22:22:59+09:00"
      xml.elements["ListBucketResult/Contents[3]/ETag"].text.should == "8059cabc22e766aea3c60ce67a82075e"
      xml.elements["ListBucketResult/Contents[3]/Size"].text.should == "8"
      xml.elements["ListBucketResult/Contents[3]/StorageClass"].text.should == "STANDARD"
      xml.elements["ListBucketResult/Contents[4]"].should == nil
    end
  end

  context 'given valid bucketname and prefix' do
    it 'should return filtered object-list' do
      get '/castoro/?prefix=hoge/'
  
      last_response.should be_ok
      xml = REXML::Document.new last_response.body
      xml.elements["ListBucketResult/Name"].text.should == "castoro"
      xml.elements["ListBucketResult/Prefix"].text.should == "hoge/"
      xml.elements["ListBucketResult/Marker"].text.should == nil
      xml.elements["ListBucketResult/MaxKeys"].text.should == "1000"
      xml.elements["ListBucketResult/IsTruncated"].text.should == "false"
      xml.elements["ListBucketResult/Contents[1]/Key"].text.should == "hoge/fuga.jpg"
      xml.elements["ListBucketResult/Contents[1]/LastModified"].text.should == "2011-07-22T21:23:41+09:00"
      xml.elements["ListBucketResult/Contents[1]/ETag"].text.should == "73feffa4b7f6bb68e44cf984c85f6e88"
      xml.elements["ListBucketResult/Contents[1]/Size"].text.should == "3"
      xml.elements["ListBucketResult/Contents[1]/StorageClass"].text.should == "STANDARD"
      xml.elements["ListBucketResult/Contents[2]/Key"].text.should == "hoge/piyo.gif"
      xml.elements["ListBucketResult/Contents[2]/LastModified"].text.should == "2011-07-22T22:22:59+09:00"
      xml.elements["ListBucketResult/Contents[2]/ETag"].text.should == "8059cabc22e766aea3c60ce67a82075e"
      xml.elements["ListBucketResult/Contents[2]/Size"].text.should == "8"
      xml.elements["ListBucketResult/Contents[2]/StorageClass"].text.should == "STANDARD"
      xml.elements["ListBucketResult/Contents[3]"].should == nil
    end
  end

  context 'given invalid bucketname' do
    it 'should return NoSuchBucket response' do
      get '/not_exists_bucket/'

      last_response.should be_not_found
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should == "NoSuchBucket"
      xml.elements["Error/Message"].text.should == "The specified bucket does not exist"
      xml.elements["Error/BucketName"].text.should == "not_exists_bucket"
      xml.elements["Error/RequestId"].text.should == nil
      xml.elements["Error/HostId"].text.should == nil
    end
  end

end

