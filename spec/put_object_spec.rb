
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'PUT Object' do
  include Rack::Test::Methods

  before(:all) do

    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
    FileUtils.mkdir_p S3Adapter::Adapter::BASE

    S3Object.delete_all
  end

  context "given bucketname and objectkey(hoge/fuga/piyo.txt)" do
    before(:all) do
      put "/castoro/hoge/fuga/piyo.txt", "abcd", "CONTENT_LENGTH" => "4"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return specified object value." do
      last_response.body.should be_empty
    end

  end

  context "given bucketname and objectkey(foo/bar/baz.txt)" do
    before(:all) do
      put "/castoro/foo/bar/baz.txt", "abcd", "CONTENT_LENGTH" => "4"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return specified object value." do
      last_response.body.should be_empty
    end

    context "should get object(foo/bar/baz.txt)" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers" do
        last_response.header["etag"].should           == "e2fc714c4727ee9395f324cd2e7f331f"
        last_response.header["content-length"].should == "4"
        last_response.header["content-type"].should   == "binary/octet-stream"
        last_response.header["accept-ranges"].should  == "bytes"
      end

      it "should return specified object value." do
        last_response.body.should == "abcd"
      end

      context "override the same object(foo/bar/baz.txt)" do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "01234567", "CONTENT_LENGTH" => "8"
        end

        it "should return response code 200." do
          last_response.should be_ok
        end

        it "should return specified object value." do
          last_response.body.should be_empty
        end

        context "should get override object(foo/bar/baz.txt)" do
          before(:all) do
            get "/castoro/foo/bar/baz.txt"
          end

          it "should return response code 200." do
            last_response.should be_ok
          end

          it "should return override response headers" do
            last_response.header["etag"].should           == "2e9ec317e197819358fbc43afca7d837"
            last_response.header["content-length"].should == "8"
            last_response.header["content-type"].should   == "binary/octet-stream"
            last_response.header["accept-ranges"].should  == "bytes"
          end

          it "should return override object value." do
            last_response.body.should == "01234567"
          end

        end
      end
    end
  end

  context "given invalid bucketname" do
    before(:all) do
      put "/hoge/foo/bar/baz.txt"
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

  describe "request headers" do
    context "given Cache-Control header" do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "HTTP_CACHE_CONTROL" => "no-cache",
          "CONTENT_LENGTH"     => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should seted Cache-Control metadata" do
        head "/castoro/foo/bar/baz.txt"
        last_response.header["cache-control"].should  == "no-cache"
      end
    end

    context "given Content-Disposition header" do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "HTTP_CONTENT_DISPOSITION" => "attachment;filename=origin",
          "CONTENT_LENGTH"           => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should seted Content-Disposition metadata" do
        head "/castoro/foo/bar/baz.txt"
        last_response.header["content-disposition"].should == "attachment;filename=origin"
      end
    end

    context "given Content-Encoding header" do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "HTTP_CONTENT_ENCODING" => "gzip",
          "CONTENT_LENGTH"        => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should seted Content-Encoding metadata" do
        head "/castoro/foo/bar/baz.txt"
        last_response.header["content-encoding"].should == "gzip"
      end
    end

    context "Content-Length" do
      context "given Content-Length header less than content size" do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "abcd", "CONTENT_LENGTH" => "2"
        end

        it "should return response code 200." do
          last_response.should be_ok
        end

        it "should seted Content-Encoding metadata" do
          get "/castoro/foo/bar/baz.txt"
          last_response.header["content-length"].should == "2"
          last_response.body.should == "ab"
        end
      end

      context "given invalid Content-Length header" do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "abcd", "CONTENT_LENGTH" => "hoge"
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end
      end

      context "no given Content-Length header" do
        before(:all) do
          put "/castoro/foo/bar/baz.txt"
        end

        it "should return response code 411." do
          last_response.status.should == 411
        end

        it "should return MissingContentLength response body." do
          xml = REXML::Document.new last_response.body
          xml.elements["Error/Code"].text.should    == "MissingContentLength"
          xml.elements["Error/Message"].text.should == "You must provide the Content-Length HTTP header."
          xml.elements["Error/RequestId"].text.should be_nil
          xml.elements["Error/HostId"].text.should be_nil
        end
      end

    end

    context "Content-MD5" do
      context "given correct Content-MD5 header" do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "abcd",
            "HTTP_CONTENT_MD5" => "e2fc714c4727ee9395f324cd2e7f331f",
            "CONTENT_LENGTH"   => "4"
        end

        it "should return response code 200." do
          last_response.should be_ok
        end

        it "should seted Content-MD5 metadata" do
          head "/castoro/foo/bar/baz.txt"
          last_response.header["etag"].should == "e2fc714c4727ee9395f324cd2e7f331f"
        end
      end

      context "given unmatch Content-MD5 header" do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "abcd",
            "HTTP_CONTENT_MD5" => "hoge",
            "CONTENT_LENGTH"   => "4"
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end

        it "should return InvalidDigest response body." do
          xml = REXML::Document.new last_response.body
          xml.elements["Error/Code"].text.should        == "InvalidDigest"
          xml.elements["Error/Message"].text.should     == "The Content-MD5 you specified was invalid."
          xml.elements["Error/RequestId"].text.should be_nil
          xml.elements["Error/Content_MD5"].text.should == "hoge"
          xml.elements["Error/HostId"].text.should be_nil
        end
      end
    end

    context "given Content-Type header" do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "CONTENT_TYPE"   => "application/pdf",
          "CONTENT_LENGTH" => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should seted Content-Encoding metadata" do
        head "/castoro/foo/bar/baz.txt"
        last_response.header["content-type"].should == "application/pdf"
      end
    end

    context "given Expires header" do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "HTTP_EXPIRES"   => "1000000",
          "CONTENT_LENGTH" => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should seted Expires metadata" do
        head "/castoro/foo/bar/baz.txt"
        last_response.header["expires"].should == "1000000"
      end

    end

  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
