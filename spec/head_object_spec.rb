
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'HEAD Object' do
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
    before(:all) do
      head "/castoro/foo/bar/baz.txt"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers" do
      last_response.header["last-modified"].should  == "Thu, 21 Jul 2011 10:14:36 GMT"
      last_response.header["etag"].should           == "ea703e7aa1efda0064eaa507d9e8ab7e"
      last_response.header["content-type"].should   == "application/octet-stream"
      last_response.header["accept-ranges"].should  == "bytes"
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  context "given valid bucketname and objectkey(hoge/fuga/piyo.txt)" do
    before(:all) do
      head "/castoro/hoge/fuga/piyo.txt"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers" do
      last_response.header["last-modified"].should  == "Fri, 13 May 2011 05:43:24 GMT"
      last_response.header["etag"].should           == "02ccdb34c1f7a8c84b72e003ddd77173"
      last_response.header["content-type"].should   == "text/plain"
      last_response.header["accept-ranges"].should  == "bytes"
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  context "given invalid bucketname" do
    before(:all) do
      head "/hoge/foo/bar/baz.txt"
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  context "given invalid objectkey" do
    before(:all) do
      head "/castoro/foo/foo/foo.txt"
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  describe "request headers" do
    context "given Range header within content-length" do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_RANGE" => "bytes=0-2"
      end

      it "should return response code 206." do
        last_response.status.should == 206
      end

      it "should return response headers" do
        last_response.header["last-modified"].should  == "Thu, 21 Jul 2011 10:14:36 GMT"
        last_response.header["etag"].should           == "ea703e7aa1efda0064eaa507d9e8ab7e"
        last_response.header["content-type"].should   == "application/octet-stream"
        last_response.header["content-range"].should  == "bytes 0-2/4"
        last_response.header["accept-ranges"].should  == "bytes"
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context "Range header syntax does not follow" do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_RANGE" => "1-3"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context "given start position out of range for Range header" do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_RANGE" => "bytes=4-10"
      end

      it "should return response code 416." do
        last_response.status.should == 416
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context "given end position out of range for Range header" do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_RANGE" => "bytes=3-10"
      end

      it "should return response code 206." do
        last_response.status.should == 206
      end

      it "should return content-range response header." do
        last_response.header["content-range"].should == "bytes 3-3/4"
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since earlier than last-modified' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_MODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since equal to last-modified' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_MODIFIED_SINCE" => "Thu, 21 Jul 2011 19:14:36 GMT"
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since header later than last-modified' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_MODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT"
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Unmodified-Since earlier than last-modified' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT"
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Unmodified-Since equal to last-modified' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_UNMODIFIED_SINCE" => "Thu, 21 Jul 2011 19:14:36 GMT"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Unmodified-Since header later than last-modified' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Match header equal to ETag' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_MATCH" => "ea703e7aa1efda0064eaa507d9e8ab7e"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Match header not equal to ETag' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_MATCH" => "02ccdb34c1f7a8c84b72e003ddd77173"
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-None-Match header not equal to ETag' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_NONE_MATCH" => "02ccdb34c1f7a8c84b72e003ddd77173"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-None-Match header equal to ETag' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {}, "HTTP_IF_NONE_MATCH" => "ea703e7aa1efda0064eaa507d9e8ab7e"
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given valid If-* and Range header' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {},
          "HTTP_RANGE"               => "bytes=0-2",
          "HTTP_IF_MODIFIED_SINCE"   => "Wed, 13 Jul 2011 19:14:36 GMT",
          "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_MATCH"            => "ea703e7aa1efda0064eaa507d9e8ab7e",
          "HTTP_IF_NONE_MATCH"       => "02ccdb34c1f7a8c84b72e003ddd77173"
      end

      it "should return response code 206." do
        last_response.status.should == 206
      end

      it "should return content-range response header." do
        last_response.header["content-range"].should == "bytes 0-2/4"
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given invalid If-* and Range header' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {},
          "HTTP_RANGE"               => "bytes=9-10",
          "HTTP_IF_MODIFIED_SINCE"   => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 20 Jul 2011 19:14:36 GMT",
          "HTTP_IF_MATCH"            => "02ccdb34c1f7a8c84b72e003ddd77173",
          "HTTP_IF_NONE_MATCH"       => "ea703e7aa1efda0064eaa507d9e8ab7e"
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since earlier than last-modified and If-None-Match equal to ETag' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {},
          "HTTP_IF_MODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT",
          "HTTP_IF_NONE_MATCH"     => "ea703e7aa1efda0064eaa507d9e8ab7e"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since later than last-modified and If-None-Match not equal to ETag' do
      before(:all) do
        head "/castoro/foo/bar/baz.txt", {},
          "HTTP_IF_MODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_NONE_MATCH"     => "02ccdb34c1f7a8c84b72e003ddd77173"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
