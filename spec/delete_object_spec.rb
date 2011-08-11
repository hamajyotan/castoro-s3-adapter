
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'DELETE Object' do
  include Rack::Test::Methods

  before(:all) do

    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
    FileUtils.mkdir_p S3Adapter::Adapter::BASE

    Castoro::Client.new() { |c|
      c.create("1.999.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "abcd" }
      }
      c.create("2.999.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
    }

    S3Object.delete_all
    S3Object.new { |o|
      o.basket_type   = 999
      o.path          = "foo/bar/baz.txt"
      o.id            = 1
      o.basket_rev    = 1
      o.last_modified = "2011-07-21T19:14:36+09:00"
      o.etag          = "ea703e7aa1efda0064eaa507d9e8ab7e"
      o.size          = 4
      o.content_type  = "application/octet-stream"
      o.save
    }
    S3Object.new { |o|
      o.basket_type   = 999
      o.path          = "hoge/fuga/piyo.txt"
      o.id            = 2
      o.basket_rev    = 1
      o.last_modified = "2011-05-13T14:43:24+09:00"
      o.etag          = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size          = 8
      o.content_type  = "text/plain"
      o.save
    }
  end

  context "given valid bucketname and objectkey(foo/bar/baz.txt)" do
    context "exist object" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end
  
      it "should return response headers" do
        last_response.header["last-modified"].should  == "Thu, 21 Jul 2011 10:14:36 GMT"
        last_response.header["etag"].should           == "ea703e7aa1efda0064eaa507d9e8ab7e"
        last_response.header["content-length"].should == "4"
        last_response.header["content-type"].should   == "application/octet-stream"
        last_response.header["accept-ranges"].should  == "bytes"
      end
  
      it "should return specified object value." do
        last_response.body.should == "abcd"
      end
    end

    context "delete object" do
      before(:all) do
        delete "/castoro/foo/bar/baz.txt"
      end

      it "should return response code 204." do
        last_response.status.should == 204
      end
  
      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context "no exist object" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt"
      end
  
      it "should return response code 404." do
        last_response.should be_not_found
      end
  
      it "should return NoSuchKey response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "NoSuchKey"
        xml.elements["Error/Message"].text.should   == "The specified key does not exist."
        xml.elements["Error/Key"].text.should       == "foo/bar/baz.txt"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

  end

  context "given valid bucketname and objectkey(hoge/fuga/piyo.txt)" do
    context "exist object" do
      before(:all) do
        get "/castoro/hoge/fuga/piyo.txt"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end
  
      it "should return response headers" do
        last_response.header["last-modified"].should  == "Fri, 13 May 2011 05:43:24 GMT"
        last_response.header["etag"].should           == "02ccdb34c1f7a8c84b72e003ddd77173"
        last_response.header["content-length"].should == "8"
        last_response.header["content-type"].should   == "text/plain"
        last_response.header["accept-ranges"].should  == "bytes"
      end
  
      it "should return specified object value." do
        last_response.body.should == "01234567"
      end
    end

    context "delete object" do
      before(:all) do
        delete "/castoro/hoge/fuga/piyo.txt"
      end

      it "should return response code 204." do
        last_response.status.should == 204
      end
  
      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context "no exist object" do
      before(:all) do
        get "/castoro/hoge/fuga/piyo.txt"
      end
  
      it "should return response code 404." do
        last_response.should be_not_found
      end
  
      it "should return NoSuchKey response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "NoSuchKey"
        xml.elements["Error/Message"].text.should   == "The specified key does not exist."
        xml.elements["Error/Key"].text.should       == "hoge/fuga/piyo.txt"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end
  end

  context "given invalid bucketname" do
    before(:all) do
      delete "/hoge/foo/bar/baz.txt"
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return NoSuchBucket response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should       == "NoSuchBucket"
      xml.elements["Error/Message"].text.should    == "The specified bucket does not exist"
      xml.elements["Error/BucketName"].text.should == "hoge"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context "given invalid objectkey" do
    before(:all) do
      delete "/castoro/foo/foo/foo.txt"
    end

    it "should return response code 204." do
      last_response.status.should == 204
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
