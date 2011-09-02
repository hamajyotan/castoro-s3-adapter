
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

  before do
    @time_mock = mock(Time)
    S3Adapter::DependencyInjector.stub!(:time_now).with(no_args).and_return { @time_mock }
    @time_mock.stub!(:utc).and_return { @time_mock }
    @time_mock.stub!(:iso8601).and_return { '2011-08-26T01:14:09Z' }
  end

  context "given bucketname and objectkey(hoge/fuga/piyo.txt)" do
    before do
      @rev = find_by_bucket_and_path('castoro', 'hoge/fuga/piyo.txt') { |obj| obj.basket_rev } || 0
      put "/castoro/hoge/fuga/piyo.txt", "abcd", "CONTENT_LENGTH" => "4"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers." do
      last_response.header["etag"].should   == "e2fc714c4727ee9395f324cd2e7f331f"
      last_response.header["server"].should == "AmazonS3"
    end

    it "should return specified object value." do
      last_response.body.should be_empty
    end

    it "should store object record." do
      find_by_bucket_and_path('castoro', 'hoge/fuga/piyo.txt') { |obj|
        obj.basket_type.should   == 999
        obj.path.should          == "hoge/fuga/piyo.txt"
        obj.basket_rev.should    == @rev + 1
        obj.last_modified.should == "2011-08-26T01:14:09Z"
        obj.etag.should          == "e2fc714c4727ee9395f324cd2e7f331f"
        obj.size.should          == 4
        obj.content_type.should  == "binary/octet-stream"
      }
    end

    it "should store file." do
      find_file_by_bucket_and_path('castoro', 'hoge/fuga/piyo.txt') { |f|
        f.read
      }.should == "abcd"
    end

  end

  context "override the same objectkey(foo/bar/baz.txt)" do
    before do
      put "/castoro/foo/bar/baz.txt", "abcd", "CONTENT_LENGTH" => "4"
      @rev = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.basket_rev } || 0
      put "/castoro/foo/bar/baz.txt", "01234567", "CONTENT_LENGTH" => "8"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers." do
      last_response.header["etag"].should   == "2e9ec317e197819358fbc43afca7d837"
      last_response.header["server"].should == "AmazonS3"
    end

    it "should return specified object value." do
      last_response.body.should be_empty
    end

    it "should store object record." do
      find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj|
        obj.basket_type.should   == 999
        obj.path.should          == "foo/bar/baz.txt"
        obj.basket_rev.should    == @rev + 1
        obj.last_modified.should == "2011-08-26T01:14:09Z"
        obj.etag.should          == "2e9ec317e197819358fbc43afca7d837"
        obj.size.should          == 8
        obj.content_type.should  == "binary/octet-stream"
      }
    end

    it "should store file." do
      find_file_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |f|
        f.read
      }.should == "01234567"
    end
  end

  context "zerobyte file put." do
    before(:all) do
      put "/castoro/zerobyte/file.txt", "", "CONTENT_LENGTH" => "0"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers." do
      last_response.header["etag"].should   == "d41d8cd98f00b204e9800998ecf8427e"
      last_response.header["server"].should == "AmazonS3"
    end

    it "should return specified object value." do
      last_response.body.should be_empty
    end

    it "should store object record." do
      find_by_bucket_and_path('castoro', 'zerobyte/file.txt') { |obj|
        obj.should_not be_nil
        obj.size.should == 0
      }
    end

    it "should store zerobyte file." do
      find_file_by_bucket_and_path('castoro', 'zerobyte/file.txt') { |f|
        f.read
      }.should == ""
    end
  end

  context "given invalid bucketname." do
    before(:all) do
      put "/hoge/foo/bar/baz.txt"
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return response headers." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
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
    context "given Cache-Control header." do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "HTTP_CACHE_CONTROL" => "no-cache",
          "CONTENT_LENGTH"     => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["etag"].should   == "e2fc714c4727ee9395f324cd2e7f331f"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should seted Cache-Control metadata." do
        find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj|
          obj.cache_control.should == "no-cache"
        }
      end
    end

    context "given Content-Disposition header." do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "HTTP_CONTENT_DISPOSITION" => "attachment;filename=origin",
          "CONTENT_LENGTH"           => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["etag"].should   == "e2fc714c4727ee9395f324cd2e7f331f"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should seted Content-Disposition metadata" do
        find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj|
          obj.content_disposition.should == "attachment;filename=origin"
        }
      end
    end

    context "given Content-Encoding header." do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "HTTP_CONTENT_ENCODING" => "gzip",
          "CONTENT_LENGTH"        => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["etag"].should   == "e2fc714c4727ee9395f324cd2e7f331f"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should seted Content-Encoding metadata." do
        find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj|
          obj.content_encoding.should == "gzip"
        }
      end
    end

    context "Content-Length" do
      context "given Content-Length header less than content size." do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "abcd", "CONTENT_LENGTH" => "2"
        end

        it "should return response code 200." do
          last_response.should be_ok
        end

        it "should return response headers." do
          last_response.header["etag"].should   == "187ef4436122d1cc2f40dc2b92f0eba0"
          last_response.header["server"].should == "AmazonS3"
        end

        it "should seted Content-Length metadata." do
          find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj|
            obj.size.should == 2
            obj.etag.should == "187ef4436122d1cc2f40dc2b92f0eba0"
          }
        end

        it "should store file." do
          find_file_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |f|
            f.read
          }.should == "ab"
        end
      end

      context "given invalid Content-Length header." do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "abcd", "CONTENT_LENGTH" => "hoge"
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end

        it "should return response headers." do
          last_response.header["server"].should == "AmazonS3"
        end
      end

      context "no given Content-Length header." do
        before(:all) do
          put "/castoro/foo/bar/baz.txt"
        end

        it "should return response code 411." do
          last_response.status.should == 411
        end

        it "should return response headers." do
          last_response.header["content-type"].should == "application/xml;charset=utf-8"
          last_response.header["server"].should       == "AmazonS3"
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
      context "given correct Content-MD5 header." do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "abcd",
            "HTTP_CONTENT_MD5" => "4vxxTEcn7pOV8yTNLn8zHw==",
            "CONTENT_LENGTH"   => "4"
        end

        it "should return response code 200." do
          last_response.should be_ok
        end

        it "should return response headers." do
          last_response.header["etag"].should   == "e2fc714c4727ee9395f324cd2e7f331f"
          last_response.header["server"].should == "AmazonS3"
        end
      end

      context "given unmatch Content-MD5 header." do
        before(:all) do
          put "/castoro/foo/bar/baz.txt", "abcd",
            "HTTP_CONTENT_MD5" => "hoge",
            "CONTENT_LENGTH"   => "4"
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end

        it "should return response headers." do
          last_response.header["content-type"].should == "application/xml;charset=utf-8"
          last_response.header["server"].should       == "AmazonS3"
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

    context "given Content-Type header." do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "CONTENT_TYPE"   => "application/pdf",
          "CONTENT_LENGTH" => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["etag"].should   == "e2fc714c4727ee9395f324cd2e7f331f"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should seted Content-Type metadata." do
        find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj|
          obj.content_type.should == "application/pdf"
        }
      end
    end

    context "given Expires header." do
      before(:all) do
        put "/castoro/foo/bar/baz.txt", "abcd",
          "HTTP_EXPIRES"   => "1000000",
          "CONTENT_LENGTH" => "4"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["etag"].should   == "e2fc714c4727ee9395f324cd2e7f331f"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should seted Content-Expires metadata." do
        find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj|
          obj.expires.should == "1000000"
        }
      end
    end

  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
