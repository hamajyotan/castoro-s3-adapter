
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'GET Object' do
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
    User.delete_all
    User.new { |u|
      u.display_name = "s3adapter_user"
      @access_key_id     = u.access_key_id     = "XXXXXXXXXXXXXXXXXXXX"
      @secret_access_key = u.secret_access_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      u.save
    }
  end

  context "given valid bucketname and objectkey(foo/bar/baz.txt)" do
    before(:all) do
      path = "/castoro/foo/bar/baz.txt"
      signature = aws_signature(@secret_access_key, "GET", path, {})
      get path, {}, "HTTP_HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers." do
      last_response.header["last-modified"].should  == "Thu, 21 Jul 2011 10:14:36 GMT"
      last_response.header["etag"].should           == "ea703e7aa1efda0064eaa507d9e8ab7e"
      last_response.header["content-length"].should == "4"
      last_response.header["content-type"].should   == "application/octet-stream"
      last_response.header["accept-ranges"].should  == "bytes"
      last_response.header["server"].should         == "AmazonS3"
    end

    it "should return specified object value." do
      last_response.body.should == "abcd"
    end
  end

  context "given valid bucketname and objectkey(hoge/fuga/piyo.txt)" do
    before(:all) do
      path = "/castoro/hoge/fuga/piyo.txt"
      signature = aws_signature(@secret_access_key, "GET", path, {})
      get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers." do
      last_response.header["last-modified"].should  == "Fri, 13 May 2011 05:43:24 GMT"
      last_response.header["etag"].should           == "02ccdb34c1f7a8c84b72e003ddd77173"
      last_response.header["content-length"].should == "8"
      last_response.header["content-type"].should   == "text/plain"
      last_response.header["accept-ranges"].should  == "bytes"
      last_response.header["server"].should         == "AmazonS3"
    end

    it "should return specified object value." do
      last_response.body.should == "01234567"
    end
  end

  context "given invalid bucketname" do
    before(:all) do
      path = "/hoge/foo/bar/baz.txt"
      signature = aws_signature(@secret_access_key, "GET", path, {})
      get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return response header." do
      last_response.header["server"].should == "AmazonS3"
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
      path = "/castoro/foo/foo/foo.txt"
      signature = aws_signature(@secret_access_key, "GET", path,{})
      get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return response header." do
      last_response.header["server"].should == "AmazonS3"
    end

    it "should return NoSuchKey response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should      == "NoSuchKey"
      xml.elements["Error/Message"].text.should   == "The specified key does not exist."
      xml.elements["Error/Key"].text.should       == "foo/foo/foo.txt"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  describe "request parameters" do
    context "given response-cache-control parameter" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt?response-cache-control=hoge.cache-control"
        signature = aws_signature(@secret_access_key, "GET", path, {})
        get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return override specified cache-control of response headers." do
        last_response.header["cache-control"].should == "hoge.cache-control"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value." do
        last_response.body.should == "abcd"
      end
    end

    context "given response-content-disposition parameter" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt?response-content-disposition=attachment;filename=hoge-disposition.txt"
        signature = aws_signature(@secret_access_key, "GET", path, {})
        get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return override specified content-disposition of response headers." do
        last_response.header["content-disposition"].should == "attachment;filename=hoge-disposition.txt"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value." do
        last_response.body.should == "abcd"
      end
    end

    context "given response-content-encoding parameter" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt?response-content-encoding=hoge.encoding"
        signature = aws_signature(@secret_access_key, "GET", path, {})
        get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return specified content-encoding of response headers." do
        last_response.header["content-encoding"].should == "hoge.encoding"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value." do
        last_response.body.should == "abcd"
      end
    end

    context "given response-content-language parameter" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt?response-content-language=hoge.language"
        signature = aws_signature(@secret_access_key, "GET", path, {})
        get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return override specified content-language of response headers." do
        last_response.header["content-language"].should == "hoge.language"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value." do
        last_response.body.should == "abcd"
      end
    end

    context "given response-content-type parameter" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt?response-content-type=hoge.content-type"
        signature = aws_signature(@secret_access_key, "GET", path, {})
        get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return override specified content-type of response headers." do
        last_response.header["content-type"].should == "hoge.content-type"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value." do
        last_response.body.should == "abcd"
      end
    end

    context "given response-expires parameter" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt?response-expires=hoge-expires"
        signature = aws_signature(@secret_access_key, "GET", path, {})
        get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return override specified expires of response headers." do
        last_response.header["expires"].should == "hoge-expires"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value." do
        last_response.body.should == "abcd"
      end
    end

    context "given response-* parameters" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt?response-cache-control=hoge.cache-control" <<
            "&response-content-disposition=attachment;filename=hoge-disposition.txt" <<
            "&response-content-encoding=hoge.encoding" <<
            "&response-content-language=hoge.language" <<
            "&response-content-type=hoge.content-type" <<
            "&response-expires=hoge-expires"
        signature = aws_signature(@secret_access_key, "GET", path, {})
        get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return override specified response headers." do
        last_response.header["cache-control"].should       == "hoge.cache-control"
        last_response.header["content-disposition"].should == "attachment;filename=hoge-disposition.txt"
        last_response.header["content-encoding"].should    == "hoge.encoding"
        last_response.header["content-language"].should    == "hoge.language"
        last_response.header["content-type"].should        == "hoge.content-type"
        last_response.header["expires"].should             == "hoge-expires"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value." do
        last_response.body.should == "abcd"
      end
    end

    context "given duplicate of the same parameters" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt?response-cache-control=hoge.cache-control" <<
            "&response-cache-control=fuga.cache-control" <<
            "&response-content-disposition=attachment;filename=hoge-disposition.txt" <<
            "&response-content-disposition=attachment;filename=fuga-disposition.txt" <<
            "&response-content-encoding=hoge.encoding" <<
            "&response-content-encoding=fuga.encoding" <<
            "&response-content-language=hoge.language" <<
            "&response-content-language=fuga.language" <<
            "&response-content-type=hoge.content-type" <<
            "&response-content-type=fuga.content-type" <<
            "&response-expires=hoge-expires" <<
            "&response-expires=fuga-expires"
        signature = aws_signature(@secret_access_key, "GET", path, {})
        get path, {}, "HTTP_AUTHORIZATION" => "AWS #{@access_key_id}:#{signature}"
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return override specified response headers." do
        last_response.header["cache-control"].should       == "hoge.cache-control"
        last_response.header["content-disposition"].should == "attachment;filename=hoge-disposition.txt"
        last_response.header["content-encoding"].should    == "hoge.encoding"
        last_response.header["content-language"].should    == "hoge.language"
        last_response.header["content-type"].should        == "hoge.content-type"
        last_response.header["expires"].should             == "hoge-expires"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end
  end

  describe "request headers" do
    context "given Range header within content-length" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_RANGE" => "bytes=0-2"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 206." do
        last_response.status.should == 206
      end

      it "should return response headers" do
        last_response.header["last-modified"].should  == "Thu, 21 Jul 2011 10:14:36 GMT"
        last_response.header["etag"].should           == "ea703e7aa1efda0064eaa507d9e8ab7e"
        last_response.header["content-length"].should == "3"
        last_response.header["content-type"].should   == "application/octet-stream"
        last_response.header["content-range"].should  == "bytes 0-2/4"
        last_response.header["accept-ranges"].should  == "bytes"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified range object value response body." do
        last_response.body.should == "abc"
      end
    end

    context "Range header syntax does not follow" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_RANGE" => "1-3"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end

    context "given start position out of range for Range header" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_RANGE" => "bytes=4-10"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 416." do
        last_response.status.should == 416
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return InvalidRange response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should             == "InvalidRange"
        xml.elements["Error/Message"].text.should          == "The requested range is not satisfiable"
        xml.elements["Error/ActualObjectSize"].text.should == "4"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
        xml.elements["Error/RangeRequested"].text.should   == "bytes=4-10"
      end
    end

    context "given end position out of range for Range header" do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_RANGE" => "bytes=3-10"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 206." do
        last_response.status.should == 206
      end

      it "should return content-range response headers." do
        last_response.header["content-range"].should == "bytes 3-3/4"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified range object value response body." do
        last_response.body.should == "d"
      end
    end

    context 'given If-Modified-Since earlier than last-modified' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_MODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end

    context 'given If-Modified-Since equal to last-modified' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_MODIFIED_SINCE" => "Thu, 21 Jul 2011 19:14:36 GMT"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since header later than last-modified' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_MODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Unmodified-Since earlier than last-modified' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_UNMODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return PreconditionFailed response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "PreconditionFailed"
        xml.elements["Error/Message"].text.should   == "At least one of the pre-conditions you specified did not hold"
        xml.elements["Error/Condition"].text.should == "If-Unmodified-Since"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'given If-Unmodified-Since equal to last-modified' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_UNMODIFIED_SINCE" => "Thu, 21 Jul 2011 19:14:36 GMT"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end

    context 'given If-Unmodified-Since header later than last-modified' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_UNMODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end

    context 'given If-Match header equal to ETag' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_MATCH" => "ea703e7aa1efda0064eaa507d9e8ab7e"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end

    context 'given If-Match header not equal to ETag' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_MATCH" => "02ccdb34c1f7a8c84b72e003ddd77173"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return PreconditionFailed response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "PreconditionFailed"
        xml.elements["Error/Message"].text.should   == "At least one of the pre-conditions you specified did not hold"
        xml.elements["Error/Condition"].text.should == "If-Match"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'given If-None-Match header not equal to ETag' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_NONE_MATCH" => "02ccdb34c1f7a8c84b72e003ddd77173"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end

    context 'given If-None-Match header equal to ETag' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {"HTTP_IF_NONE_MATCH" => "ea703e7aa1efda0064eaa507d9e8ab7e"}
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given valid If-* and Range header' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_RANGE"       => "bytes=0-2",
          "HTTP_IF_MODIFIED_SINCE"   => "Wed, 13 Jul 2011 19:14:36 GMT",
          "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_MATCH"            => "ea703e7aa1efda0064eaa507d9e8ab7e",
          "HTTP_IF_NONE_MATCH"       => "02ccdb34c1f7a8c84b72e003ddd77173"
        }
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 206." do
        last_response.status.should == 206
      end

      it "should return content-range response headers." do
        last_response.header["content-range"].should == "bytes 0-2/4"
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abc"
      end
    end

    context 'given invalid If-* and Range header' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_RANGE"       => "bytes=9-10",
          "HTTP_IF_MODIFIED_SINCE"   => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 20 Jul 2011 19:14:36 GMT",
          "HTTP_IF_MATCH"            => "02ccdb34c1f7a8c84b72e003ddd77173",
          "HTTP_IF_NONE_MATCH"       => "ea703e7aa1efda0064eaa507d9e8ab7e"
        }
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it 'should return PreconditionaFailed response body.' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "PreconditionFailed"
        xml.elements["Error/Message"].text.should   == "At least one of the pre-conditions you specified did not hold"
        xml.elements["Error/Condition"].text.should == "If-Unmodified-Since"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'given If-Modified-Since earlier than last-modified and If-None-Match equal to ETag' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_IF_MODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT",
          "HTTP_IF_NONE_MATCH"     => "ea703e7aa1efda0064eaa507d9e8ab7e"
        }
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end

    context 'given If-Modified-Since later than last-modified and If-None-Match not equal to ETag' do
      before(:all) do
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_IF_MODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_NONE_MATCH"     => "02ccdb34c1f7a8c84b72e003ddd77173"
        }
        signature = aws_signature(@secret_access_key, "GET", path, headers)
        headers["HTTP_AUTHORIZATION"] = "AWS #{@access_key_id}:#{signature}"
        get path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return specified object value response body." do
        last_response.body.should == "abcd"
      end
    end

  end

  describe "anonymous request" do
    context "given response-cache-control parameter" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt?response-cache-control=hoge.cache-control"
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return InvalidRequest response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "InvalidRequest"
        xml.elements["Error/Message"].text.should   == "Request specific response headers cannot be used for anonymous GET requests."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end

    end

    context "given response-content-disposition parameter" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt?response-content-disposition=attachment;filename=hoge-disposition.txt"
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return InvalidRequest response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "InvalidRequest"
        xml.elements["Error/Message"].text.should   == "Request specific response headers cannot be used for anonymous GET requests."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end

    end

    context "given response-content-encoding parameter" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt?response-content-encoding=hoge.encoding"
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return InvalidRequest response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "InvalidRequest"
        xml.elements["Error/Message"].text.should   == "Request specific response headers cannot be used for anonymous GET requests."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end

    end

    context "given response-content-language parameter" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt?response-content-language=hoge.language"
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return InvalidRequest response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "InvalidRequest"
        xml.elements["Error/Message"].text.should   == "Request specific response headers cannot be used for anonymous GET requests."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end

    end

    context "given response-content-type parameter" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt?response-content-type=hoge.content-type"
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return InvalidRequest response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "InvalidRequest"
        xml.elements["Error/Message"].text.should   == "Request specific response headers cannot be used for anonymous GET requests."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end

    end

    context "given response-expires parameter" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt?response-expires=hoge-expires"
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return InvalidRequest response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "InvalidRequest"
        xml.elements["Error/Message"].text.should   == "Request specific response headers cannot be used for anonymous GET requests."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end

    end

    context "given response-* parameters" do
      before(:all) do
        get "/castoro/foo/bar/baz.txt?response-cache-control=hoge.cache-control" <<
            "&response-content-disposition=attachment;filename=hoge-disposition.txt" <<
            "&response-content-encoding=hoge.encoding" <<
            "&response-content-language=hoge.language" <<
            "&response-content-type=hoge.content-type" <<
            "&response-expires=hoge-expires"
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response header." do
        last_response.header["server"].should == "AmazonS3"
      end

      it "should return InvalidRequest response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "InvalidRequest"
        xml.elements["Error/Message"].text.should   == "Request specific response headers cannot be used for anonymous GET requests."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end

    end

  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
