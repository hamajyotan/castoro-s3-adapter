
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

    @users = {
      'test_user1' => {
        'access-key-id' => 'XXXXXXXXXXXXXXXXXXXX',
        'secret-access-key' => 'AStringOfSecretAccessKey',
      },
      'test_user2' => {
        'access-key-id' => 'AStringOfAccessKeyId',
        'secret-access-key' => 'VeryVeryVerySecretAccessKey',
      },
    }
    User.delete_all
    @users.each { |k,v|
      User.new { |u|
        u.access_key_id = v['access-key-id']
        u.secret_access_key = v['secret-access-key']
        u.display_name = k
        u.save
      }
    }

    S3Object.delete_all
    S3Object.new { |o|
      o.basket_type      = 999
      o.path             = "foo/bar/baz.txt"
      o.id               = 1
      o.basket_rev       = 1
      o.last_modified    = "2011-07-21T19:14:36+09:00"
      o.etag             = "ea703e7aa1efda0064eaa507d9e8ab7e"
      o.size             = 4
      o.content_type     = "application/octet-stream"
      o.owner_access_key = "XXXXXXXXXXXXXXXXXXXX"
      o.acl              = {'account' => {'XXXXXXXXXXXXXXXXXXXX' => [S3Adapter::Acl::READ]}}
      o.meta             = {"title" => "the title"}
      o.save
    }
    S3Object.new { |o|
      o.basket_type      = 999
      o.path             = "hoge/fuga/piyo.txt"
      o.id               = 2
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "AStringOfAccessKeyId"
      o.acl              = {'account' => {'XXXXXXXXXXXXXXXXXXXX' => [S3Adapter::Acl::READ]}}
      o.save
    }
    @time = Time.now
  end

  before(:each) do # mock cannot be used by before(:all).
    @time_mock = mock(Time)
    S3Adapter::DependencyInjector.stub!(:time_now).with(no_args).and_return { @time_mock }
    @time_mock.stub!(:utc).and_return { @time.utc }
    @time_mock.stub!(:iso8601).and_return { @time.iso8601 }
  end

  context 'given invalid access_key_id of authorization header' do
    before(:all) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz.txt"
      headers = {}
      signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS invalid_access_key_id:#{signature}"
      head path, {}, headers
    end

    it 'should return code 403' do
      last_response.status.should == 403
    end

    it 'should return response headers' do
      last_response.header['server'].should == 'AmazonS3'
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  context 'given invalid secret_access_key of authorization header' do
    before(:each) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz.txt"
      headers = {}
      @signature = aws_signature("invalid_secret_access_key", 'HEAD', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{@signature}"
      head path, {}, headers
    end

    it 'should return code 403' do
      last_response.status.should == 403
    end

    it 'should return response headers' do
      last_response.header['server'].should == 'AmazonS3'
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  context "given valid bucketname and objectkey(foo/bar/baz.txt)" do
    before(:all) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz.txt"
      headers = { "HTTP_DATE" => @time.httpdate }
      signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      head path, {}, headers
    end

    it "should return response code 200." do
      last_response.status.should == 200
    end

    it "should return response headers" do
      last_response.header["last-modified"].should  == "Thu, 21 Jul 2011 10:14:36 GMT"
      last_response.header["etag"].should           == "ea703e7aa1efda0064eaa507d9e8ab7e"
      last_response.header["content-type"].should   == "application/octet-stream"
      last_response.header["accept-ranges"].should  == "bytes"
      last_response.header['x-amz-meta-title'].should == 'the title'
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  context "given valid bucketname and objectkey(hoge/fuga/piyo.txt)" do
    before(:all) do
      @user = 'test_user1'
      path = "/castoro/hoge/fuga/piyo.txt"
      headers = { "HTTP_DATE" => @time.httpdate }
      signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      head path, {}, headers
    end

    it "should return response code 200." do
      last_response.status.should == 200
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
      @user = 'test_user1'
      path = "/hoge/foo/bar/baz.txt"
      headers = { "HTTP_DATE" => @time.httpdate }
      signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      head path, {}, headers
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it 'should return response headers' do
      last_response.header['server'].should == 'AmazonS3'
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  context "given invalid objectkey" do
    before(:all) do
      @user = 'test_user1'
      path = "/castoro/foo/foo/foo.txt"
      headers = { "HTTP_DATE" => @time.httpdate }
      signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      head path, {}, headers
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it 'should return response headers' do
      last_response.header['server'].should == 'AmazonS3'
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  describe "request headers" do
    context "given Range header within content-length" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"  => @time.httpdate,
          "HTTP_RANGE" => "bytes=0-2"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 206." do
        last_response.status.should == 206
        last_response.header['x-amz-meta-title'].should == 'the title'
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
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"  => @time.httpdate,
          "HTTP_RANGE" => "1-3"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers" do
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context "given start position out of range for Range header" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"  => @time.httpdate,
          "HTTP_RANGE" => "bytes=4-10"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
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
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"  => @time.httpdate,
          "HTTP_RANGE" => "bytes=3-10"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 206." do
        last_response.status.should == 206
      end

      it "should return content-range response header." do
        last_response.header["content-range"].should == "bytes 3-3/4"
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since earlier than last-modified' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"              => @time.httpdate,
          "HTTP_IF_MODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers" do
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since equal to last-modified' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"              => @time.httpdate,
          "HTTP_IF_MODIFIED_SINCE" => "Thu, 21 Jul 2011 19:14:36 GMT"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return nothing metadata header" do
        last_response.header['x-amz-meta-title'].should == nil
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since header later than last-modified' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"              => @time.httpdate,
          "HTTP_IF_MODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return nothing metadata header" do
        last_response.header['x-amz-meta-title'].should == nil
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Unmodified-Since earlier than last-modified' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"                => @time.httpdate,
          "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
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
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"                => @time.httpdate,
          "HTTP_IF_UNMODIFIED_SINCE" => "Thu, 21 Jul 2011 19:14:36 GMT"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers" do
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Unmodified-Since header later than last-modified' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"                => @time.httpdate,
          "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers" do
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Match header equal to ETag' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"     => @time.httpdate,
          "HTTP_IF_MATCH" => "ea703e7aa1efda0064eaa507d9e8ab7e"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return resopnse headers" do
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Match header not equal to ETag' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"     => @time.httpdate,
          "HTTP_IF_MATCH" => "02ccdb34c1f7a8c84b72e003ddd77173"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
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
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"          => @time.httpdate,
          "HTTP_IF_NONE_MATCH" => "02ccdb34c1f7a8c84b72e003ddd77173"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers" do
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-None-Match header equal to ETag' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"          => @time.httpdate,
          "HTTP_IF_NONE_MATCH" => "ea703e7aa1efda0064eaa507d9e8ab7e"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 304." do
        last_response.status.should == 304
      end

      it "should return nothing metadata header" do
        last_response.header['x-amz-meta-title'].should == nil
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given valid If-* and Range header' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"                => @time.httpdate,
          "HTTP_RANGE"               => "bytes=0-2",
          "HTTP_IF_MODIFIED_SINCE"   => "Wed, 13 Jul 2011 19:14:36 GMT",
          "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_MATCH"            => "ea703e7aa1efda0064eaa507d9e8ab7e",
          "HTTP_IF_NONE_MATCH"       => "02ccdb34c1f7a8c84b72e003ddd77173"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 206." do
        last_response.status.should == 206
      end

      it "should return content-range response header." do
        last_response.header["content-range"].should == "bytes 0-2/4"
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given invalid If-* and Range header' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"                => @time.httpdate,
          "HTTP_RANGE"               => "bytes=9-10",
          "HTTP_IF_MODIFIED_SINCE"   => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_UNMODIFIED_SINCE" => "Wed, 20 Jul 2011 19:14:36 GMT",
          "HTTP_IF_MATCH"            => "02ccdb34c1f7a8c84b72e003ddd77173",
          "HTTP_IF_NONE_MATCH"       => "ea703e7aa1efda0064eaa507d9e8ab7e"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
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
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"              => @time.httpdate,
          "HTTP_IF_MODIFIED_SINCE" => "Wed, 13 Jul 2011 19:14:36 GMT",
          "HTTP_IF_NONE_MATCH"     => "ea703e7aa1efda0064eaa507d9e8ab7e"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers" do
        last_response.header['x-amz-meta-title'].should == 'the title'
      end

      it "should return no response body." do
        last_response.body.should be_empty
      end
    end

    context 'given If-Modified-Since later than last-modified and If-None-Match not equal to ETag' do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz.txt"
        headers = {
          "HTTP_DATE"              => @time.httpdate,
          "HTTP_IF_MODIFIED_SINCE" => "Wed, 27 Jul 2011 19:14:36 GMT",
          "HTTP_IF_NONE_MATCH"     => "02ccdb34c1f7a8c84b72e003ddd77173"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'HEAD', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        head path, {}, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers" do
        last_response.header['x-amz-meta-title'].should == 'the title'
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
