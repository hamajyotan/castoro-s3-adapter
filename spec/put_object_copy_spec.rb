
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'PUT Object Copy' do
  include Rack::Test::Methods

  before(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
    FileUtils.mkdir_p S3Adapter::Adapter::BASE

    Castoro::Client.new() { |c|
      c.create("1.999.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "abcd" }
      }
      c.create("2.1000.1") { |host, path|
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
        u.access_key_id     = v['access-key-id']
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
      o.save
    }
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "hoge/fuga/piyo.txt"
      o.id               = 2
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "AStringOfAccessKeyId"
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
      path = "/castoro/foo/bar/baz_copy.txt"
      headers = { "HTTP_X_AMZ_COPY_SOURCE" => "/castoro/foo/bar/baz.txt" }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS invalid_access_key_id:#{signature}"
      put path, nil, headers
    end

    it 'should return code 403' do
      last_response.status.should == 403
    end

    it 'should return response headers' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return InvalidAccessKeyId response body' do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should == "InvalidAccessKeyId"
      xml.elements["Error/Message"].text.should == "The AWS Access Key Id you provided does not exist in our records."
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
      xml.elements["Error/AWSAccessKeyId"].text.should == "invalid_access_key_id"
    end
  end

  context 'given invalid secret_access_key of authorization header' do
    before(:each) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz_copy.txt"
      headers = { "HTTP_X_AMZ_COPY_SOURCE" => "/castoro/foo/bar/baz.txt" }
      @signature = aws_signature("invalid_secret_access_key", 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{@signature}"
      put path, nil, headers
    end

    it 'should return code 403' do
      last_response.status.should == 403
    end

    it 'should return response headers' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return SignatureDoesNotMatch response body' do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should == "SignatureDoesNotMatch"
      xml.elements["Error/Message"].text.should == "The request signature we calculated does not match the signature you provided. Check your key and signing method."
      xml.elements["Error/StringToSignBytes"].text.should == "50 55 54 0a 0a 0a 0a 78 2d 61 6d 7a 2d 63 6f 70 79 2d 73 6f 75 72 63 65 3a 2f 63 61 73 74 6f 72 6f 2f 66 6f 6f 2f 62 61 72 2f 62 61 7a 2e 74 78 74 0a 2f 63 61 73 74 6f 72 6f 2f 66 6f 6f 2f 62 61 72 2f 62 61 7a 5f 63 6f 70 79 2e 74 78 74"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
      xml.elements["Error/SignatureProvided"].text.should == @signature
      xml.elements["Error/StringToSign"].text.should == "PUT\n\n\n\nx-amz-copy-source:/castoro/foo/bar/baz.txt\n/castoro/foo/bar/baz_copy.txt"
      xml.elements["Error/AWSAccessKeyId"].text.should == "XXXXXXXXXXXXXXXXXXXX"
    end
  end

  context "given source same bucketname objectkey(/castoro/foo/bar/baz.txt)" do
    before(:each) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz_copy.txt"
      headers = {
        "HTTP_DATE"              => @time.httpdate,
        "HTTP_X_AMZ_COPY_SOURCE" => "/castoro/foo/bar/baz.txt"
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      @rev = find_by_bucket_and_path('castoro', 'foo/bar/baz_copy.txt') { |obj| obj.basket_rev } || 0
      put path, nil, headers
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return CopyObjectResult response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
      xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
    end

    it "should store copied object record." do
      find_by_bucket_and_path('castoro', 'foo/bar/baz_copy.txt') { |obj|
        obj.basket_type.should      == 999
        obj.path.should             == "foo/bar/baz_copy.txt"
        obj.basket_rev.should       == @rev + 1
        obj.last_modified.should    == @time_mock.utc.iso8601
        obj.etag.should             == "ea703e7aa1efda0064eaa507d9e8ab7e"
        obj.size.should             == 4
        obj.content_type.should     == "application/octet-stream"
        obj.owner_access_key.should == "XXXXXXXXXXXXXXXXXXXX"
      }
    end

    it "should store copied file." do
      find_file_by_bucket_and_path('castoro', 'foo/bar/baz_copy.txt') { |f|
        f.read
      }.should == "abcd"
    end

  end

  context "given source same bucketname objectkey(/test/hoge/fuga/piyo.txt)" do
    before(:each) do
      @user = 'test_user1'
      path = "/test/hoge/fuga/piyo_copy.txt"
      headers = {
        "HTTP_DATE"              => @time.httpdate,
        "HTTP_X_AMZ_COPY_SOURCE" => "/test/hoge/fuga/piyo.txt"
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, nil, headers
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return CopyObjectResult response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
      xml.elements["CopyObjectResult/ETag"].text.should         == "02ccdb34c1f7a8c84b72e003ddd77173"
    end
  end

  context "given source other bucketname objectkey(/test/hoge/fuga/piyo.txt)" do
    before(:each) do
      @user = 'test_user2'
      path = "/castoro/hoge/fuga/piyo_copy.txt"
      headers = {
        "HTTP_DATE"              => @time.httpdate,
        "HTTP_X_AMZ_COPY_SOURCE" => "/test/hoge/fuga/piyo.txt"
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      @rev = find_by_bucket_and_path('castoro', 'hoge/fuga/piyo_copy.txt') { |obj| obj.basket_rev } || 0
      put path, nil, headers
    end

    it "should return response code 200." do
      last_response.should be_ok
    end

    it "should return response headers." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return CopyObjectResult response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
      xml.elements["CopyObjectResult/ETag"].text.should         == "02ccdb34c1f7a8c84b72e003ddd77173"
    end

    it "should store copied object record." do
      find_by_bucket_and_path('castoro', 'hoge/fuga/piyo_copy.txt') { |obj|
        obj.basket_type.should      == 999
        obj.path.should             == "hoge/fuga/piyo_copy.txt"
        obj.basket_rev.should       == @rev + 1
        obj.last_modified.should    == @time_mock.utc.iso8601
        obj.etag.should             == "02ccdb34c1f7a8c84b72e003ddd77173"
        obj.size.should             == 8
        obj.content_type.should     == "text/plain"
        obj.owner_access_key.should == "AStringOfAccessKeyId"
      }
    end

    it "should store copied file." do
      find_file_by_bucket_and_path('castoro', 'hoge/fuga/piyo_copy.txt') { |f|
        f.read
      }.should == "01234567"
    end

  end

  context "no given x-amz-copy-source headers" do
    before(:all) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz_copy.txt"
      headers = { "HTTP_DATE" => @time.httpdate }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, nil, headers
    end

    it "should return response code 411." do
      last_response.status.should == 411
    end

    it "should return response header." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return MissingContentLength response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should       == "MissingContentLength"
      xml.elements["Error/Message"].text.should    == "You must provide the Content-Length HTTP header."
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context "no given x-amz-copy-source headers value" do
    before(:all) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz_copy.txt"
      headers = {
        "HTTP_DATE"              => @time.httpdate,
        "HTTP_X_AMZ_COPY_SOURCE" => nil
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, nil, headers
    end

    it "should return response code 400." do
      last_response.status.should == 400
    end

    it "should return response header." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return InvalidArgument response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should          == "InvalidArgument"
      xml.elements["Error/Message"].text.should       == "Copy Source must mention the source bucket and key: sourcebucket/sourcekey"
      xml.elements["Error/ArgumentValue"].text.should == nil
      xml.elements["Error/ArgumentName"].text.should  == "x-amz-copy-source"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context "given no exist bucketname copy source" do
    before(:all) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz_copy.txt"
      headers = {
        "HTTP_DATE"              => @time.httpdate,
        "HTTP_X_AMZ_COPY_SOURCE" => "/no_exist_bucket/foo/bar/baz.txt"
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, nil, headers
    end

    it "should return response code 404." do
      last_response.status.should == 404
    end

    it "should return response headers." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return NoSuchBucket response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should       == "NoSuchBucket"
      xml.elements["Error/Message"].text.should    == "The specified bucket does not exist"
      xml.elements["Error/BucketName"].text.should == "no_exist_bucket"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context "given no exist object copy source" do
    before(:all) do
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz_copy.txt"
      headers = {
        "HTTP_DATE"              => @time.httpdate,
        "HTTP_X_AMZ_COPY_SOURCE" => "/castoro/no_exist_key"
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, nil, headers
    end

    it "should return response code 404." do
      last_response.status.should == 404
    end

    it "should return response headers." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return NoSuchKey response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should    == "NoSuchKey"
      xml.elements["Error/Message"].text.should == "The specified key does not exist."
      xml.elements["Error/Key"].text.should     == "no_exist_key"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  describe "request headers" do
    context "given x-amz-metadata-directive specified 'REPLACE'" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy_replace.txt"
        headers = {
          "HTTP_DATE"                     => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"        => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_METADATA_DIRECTIVE" => "REPLACE",
          "HTTP_CACHE_CONTROL"            => "no-cache",
          "HTTP_CONTENT_DISPOSITION"      => "attachment;filename=origin",
          "HTTP_CONTENT_ENCODING"         => "gzip",
          "CONTENT_TYPE"                  => "application/pdf",
          "HTTP_EXPIRES"                  => "1000000",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        @rev = find_by_bucket_and_path('castoro', 'foo/bar/baz_copy_replace.txt') { |obj| obj.basket_rev } || 0
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end

      it "should store override object record." do
        find_by_bucket_and_path('castoro', 'foo/bar/baz_copy_replace.txt') { |obj|
          obj.basket_type.should         == 999
          obj.path.should                == "foo/bar/baz_copy_replace.txt"
          obj.basket_rev.should          == @rev + 1
          obj.last_modified.should       == @time_mock.utc.iso8601
          obj.etag.should                == "ea703e7aa1efda0064eaa507d9e8ab7e"
          obj.size.should                == 4
          obj.cache_control.should       == "no-cache"
          obj.content_disposition.should == "attachment;filename=origin"
          obj.content_encoding.should    == "gzip"
          obj.content_type.should        == "application/pdf"
          obj.expires.should             == "1000000"
          obj.owner_access_key.should    == "XXXXXXXXXXXXXXXXXXXX"
        }
      end

    end

    context "given x-amz-metadata-directive specified 'COPY'" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy_directive.txt"
        headers = {
          "HTTP_DATE"                     => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"        => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_METADATA_DIRECTIVE" => "COPY",
          "HTTP_CACHE_CONTROL"            => "no-cache",
          "HTTP_CONTENT_DISPOSITION"      => "attachment;filename=origin",
          "HTTP_CONTENT_ENCODING"         => "gzip",
          "CONTENT_TYPE"                  => "application/pdf",
          "HTTP_EXPIRES"                  => "1000000",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        @rev = find_by_bucket_and_path('castoro', 'foo/bar/baz_copy_directive.txt') { |obj| obj.basket_rev } || 0
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end

      it "should store copied object record." do
        find_by_bucket_and_path('castoro', 'foo/bar/baz_copy_directive.txt') { |obj|
          obj.basket_type.should      == 999
          obj.path.should             == "foo/bar/baz_copy_directive.txt"
          obj.basket_rev.should       == @rev + 1
          obj.last_modified.should    == @time_mock.utc.iso8601
          obj.etag.should             == "ea703e7aa1efda0064eaa507d9e8ab7e"
          obj.size.should             == 4
          obj.content_type.should     == "application/octet-stream"
          obj.owner_access_key.should == "XXXXXXXXXXXXXXXXXXXX"
          obj.cache_control.should be_nil
          obj.content_disposition.should be_nil
          obj.content_encoding.should be_nil
          obj.expires.should be_nil
        }
      end

    end

    context "given x-amz-copy-source-if-match header equal to ETag" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                       => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"          => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_MATCH" => "ea703e7aa1efda0064eaa507d9e8ab7e",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end
    end

    context "given x-amz-copy-source-if-match header not equal to ETag" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                       => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"          => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_MATCH" => "02ccdb34c1f7a8c84b72e003ddd77173",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return PreconditionFailed response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "PreconditionFailed"
        xml.elements["Error/Message"].text.should   == "At least one of the pre-conditions you specified did not hold"
        xml.elements["Error/Condition"].text.should == "x-amz-copy-source-If-Match"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context "given x-amz-copy-source-if-none-match not equal to ETag" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                            => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"               => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_NONE_MATCH" => "02ccdb34c1f7a8c84b72e003ddd77173",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end
    end

    context "given x-amz-copy-source-if-none-match equal to ETag" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                            => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"               => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_NONE_MATCH" => "ea703e7aa1efda0064eaa507d9e8ab7e",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return PreconditionFailed response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "PreconditionFailed"
        xml.elements["Error/Message"].text.should   == "At least one of the pre-conditions you specified did not hold"
        xml.elements["Error/Condition"].text.should == "x-amz-copy-source-If-None-Match"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context "given x-amz-copy-source-if-modified-since earlier than last-modified" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                                => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"                   => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_MODIFIED_SINCE" => "Fri, 15 Jul 2011 01:14:09 GMT",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end
    end

    context "given x-amz-copy-source-if-modified-since equal to last-modified" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                                => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"                   => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_MODIFIED_SINCE" => "Thu, 21 Jul 2011 19:14:36 GMT",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return PreconditionFailed response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "PreconditionFailed"
        xml.elements["Error/Message"].text.should   == "At least one of the pre-conditions you specified did not hold"
        xml.elements["Error/Condition"].text.should == "x-amz-copy-source-If-Modified-Since"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context "given x-amz-copy-source-if-modified-since later than last-modified" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                                => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"                   => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_MODIFIED_SINCE" => "Fri, 26 Aug 2011 01:14:09 GMT",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return PreconditionFailed response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "PreconditionFailed"
        xml.elements["Error/Message"].text.should   == "At least one of the pre-conditions you specified did not hold"
        xml.elements["Error/Condition"].text.should == "x-amz-copy-source-If-Modified-Since"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context "given x-amz-copy-source-if-unmodified-since earlier than last-modified" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                                  => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"                     => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_UNMODIFIED_SINCE" => "Fri, 15 Jul 2011 01:14:09 GMT",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 412." do
        last_response.status.should == 412
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return PreconditionFailed response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should      == "PreconditionFailed"
        xml.elements["Error/Message"].text.should   == "At least one of the pre-conditions you specified did not hold"
        xml.elements["Error/Condition"].text.should == "x-amz-copy-source-If-Unmodified-Since"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context "given x-amz-copy-source-if-unmodified-since equal to last-modified" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                                  => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"                     => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_UNMODIFIED_SINCE" => "Thu, 21 Jul 2011 19:14:36 GMT",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end
    end

    context "given x-amz-copy-source-if-unmodified-since later than last-modified" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                                  => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"                     => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_UNMODIFIED_SINCE" => "Fri, 26 Aug 2011 01:14:09 GMT",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end
    end

    context "given x-amz-copy-source-if-modified-since earlier than last-modified and x-amz-copy-source-if-none-match equal to the ETag" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                                => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"                   => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_MODIFIED_SINCE" => "Fri, 15 Jul 2011 01:14:09 GMT",
          "HTTP_X_AMZ_COPY_SOURCE_IF_NONE_MATCH"     => "ea703e7aa1efda0064eaa507d9e8ab7e",
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end
    end

    context "given x-amz-copy-source-if-modified-since later than last-modified and x-amz-copy-source-if-none-match not equal to the ETag" do
      before(:each) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                                => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"                   => "/castoro/foo/bar/baz.txt",
          "HTTP_X_AMZ_COPY_SOURCE_IF_MODIFIED_SINCE" => "Fri, 15 Jul 2011 01:14:09 GMT",
          "HTTP_X_AMZ_COPY_SOURCE_IF_NONE_MATCH"     => "02ccdb34c1f7a8c84b72e003ddd77173"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 200." do
        last_response.should be_ok
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return CopyObjectResult response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["CopyObjectResult/LastModified"].text.should == @time_mock.utc.iso8601
        xml.elements["CopyObjectResult/ETag"].text.should         == "ea703e7aa1efda0064eaa507d9e8ab7e"
      end
    end

    context "given content-length header > 0" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"              => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE" => "/castoro/foo/bar/baz.txt",
          "CONTENT_LENGTH"         => 1,
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return MaxMessageLengthExceeded response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should    == "MaxMessageLengthExceeded"
        xml.elements["Error/Message"].text.should == "Your request was too big."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
        xml.elements["Error/MaxMessageLengthBytes"].text.should == "0"
      end
    end

    context "given content-length header > 0" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"              => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE" => "/castoro/foo/bar/baz.txt",
          "CONTENT_LENGTH"         => 1,
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return MaxMessageLengthExceeded response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should    == "MaxMessageLengthExceeded"
        xml.elements["Error/Message"].text.should == "Your request was too big."
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
        xml.elements["Error/MaxMessageLengthBytes"].text.should == "0"
      end
    end

  end

  describe "copies itself" do
    context "given self object copy source" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"              => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE" => "/castoro/foo/bar/baz_copy.txt"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 400." do
        last_response.status.should == 400
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return InvalidRequest response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should    == "InvalidRequest"
        xml.elements["Error/Message"].text.should == "The Source and Destination may not be the same when the MetadataDirective is Copy and storage class unspecified"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context "given self object copy source and x-amz-copy-source header specified 'REPLACE'" do
      before(:all) do
        @user = 'test_user1'
        path = "/castoro/foo/bar/baz_copy.txt"
        headers = {
          "HTTP_DATE"                     => @time.httpdate,
          "HTTP_X_AMZ_COPY_SOURCE"        => "/castoro/foo/bar/baz_copy.txt",
          "HTTP_X_AMZ_METADATA_DIRECTIVE" => "REPLACE"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put path, nil, headers
      end

      it "should return response code 403." do
        last_response.status.should == 403
      end

      it "should return response headers." do
        last_response.header["content-type"].should == "application/xml;charset=utf-8"
        last_response.header["server"].should       == "AmazonS3"
      end

      it "should return AccessDenied response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should    == "AccessDenied"
        xml.elements["Error/Message"].text.should == "Access Denied"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end
  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
