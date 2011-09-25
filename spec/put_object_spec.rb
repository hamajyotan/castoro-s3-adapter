
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'PUT Object' do
  include Rack::Test::Methods

  before(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
    FileUtils.mkdir_p S3Adapter::Adapter::BASE

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
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS invalid_access_key_id:#{signature}"
      put path, "abcd", headers
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
      path = "/castoro/foo/bar/baz.txt"
      headers = {}
      @signature = aws_signature("invalid_secret_access_key", 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{@signature}"
      put path, "abcd", headers
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
      xml.elements["Error/StringToSignBytes"].text.should == "50 55 54 0a 0a 0a 0a 2f 63 61 73 74 6f 72 6f 2f 66 6f 6f 2f 62 61 72 2f 62 61 7a 2e 74 78 74"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
      xml.elements["Error/SignatureProvided"].text.should == @signature
      xml.elements["Error/StringToSign"].text.should == "PUT\n\n\n\n/castoro/foo/bar/baz.txt"
      xml.elements["Error/AWSAccessKeyId"].text.should == "XXXXXXXXXXXXXXXXXXXX"
    end
  end

  context "given bucketname and objectkey(hoge/fuga/piyo.txt)" do
    before(:each) do
      @user = 'test_user1'
      path = '/castoro/hoge/fuga/piyo.txt'
      headers = {
        "HTTP_DATE"           => @time.httpdate,
        "CONTENT_LENGTH"      => "4",
        "HTTP_X_AMZ_META_FOO" => "foofoo",
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      @rev = find_by_bucket_and_path('castoro', 'hoge/fuga/piyo.txt') { |obj| obj.basket_rev } || 0
      put path, "abcd", headers
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
        obj.basket_type.should      == 999
        obj.path.should             == "hoge/fuga/piyo.txt"
        obj.basket_rev.should       == @rev + 1
        obj.last_modified.should    == @time_mock.utc.iso8601
        obj.etag.should             == "e2fc714c4727ee9395f324cd2e7f331f"
        obj.size.should             == 4
        obj.content_type.should     == "binary/octet-stream"
        obj.owner_access_key.should == "XXXXXXXXXXXXXXXXXXXX"
        obj.meta.should             == {'foo' => 'foofoo'}
      }
    end

    it "should store file." do
      find_file_by_bucket_and_path('castoro', 'hoge/fuga/piyo.txt') { |f|
        f.read
      }.should == "abcd"
    end

  end

  context "override the same objectkey(foo/bar/baz.txt)" do
    before(:each) do
      # first PUT Object
      @user = 'test_user1'
      path = "/castoro/foo/bar/baz.txt"
      headers = {
        "HTTP_DATE"           => @time.httpdate,
        "CONTENT_LENGTH"      => "4",
        "HTTP_X_AMZ_META_FOO" => "FOO!!",
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, "abcd", headers
      # override PUT Object
      @user = 'test_user2'
      headers = {
        "HTTP_DATE"           => @time.httpdate,
        "CONTENT_LENGTH"      => "8",
        "HTTP_X_AMZ_META_FOO" => "foofoo",
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      @rev = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.basket_rev } || 0
      put path, "01234567", headers
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
        obj.basket_type.should      == 999
        obj.path.should             == "foo/bar/baz.txt"
        obj.basket_rev.should       == @rev + 1
        obj.last_modified.should    == @time_mock.utc.iso8601
        obj.etag.should             == "2e9ec317e197819358fbc43afca7d837"
        obj.size.should             == 8
        obj.content_type.should     == "binary/octet-stream"
        obj.owner_access_key.should == "AStringOfAccessKeyId"
        obj.meta.should             == {"foo" => "foofoo"}
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
        obj.meta.should == {}
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
          xml.elements["Error/Code"].text.should == "InvalidDigest"
          xml.elements["Error/Message"].text.should == "The Content-MD5 you specified was invalid."
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

  describe 'x-amz-acl header' do
    before(:all) do
      @user = 'test_user2'
      @path = '/castoro/foo/bar/baz.txt'
    end

    context 'not given x-amz-acl header' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time.httpdate,
          'CONTENT_LENGTH' => '4',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, 'abcd', headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
      end

      it 'full_control is added to owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

    context 'private given x-amz-acl header' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time.httpdate,
          'CONTENT_LENGTH' => '4',
          'HTTP_X_AMZ_ACL' => 'private',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, 'abcd', headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
      end

      it 'full_control is added to owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

    context 'public-read given x-amz-acl header' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time.httpdate,
          'CONTENT_LENGTH' => '4',
          'HTTP_X_AMZ_ACL' => 'public-read',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, 'abcd', headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
      end

      it 'full_control is added to owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'read is added to guest' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should == [S3Adapter::Acl::READ]
      end
    end

    context 'public-read-write given x-amz-acl header' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time.httpdate,
          'CONTENT_LENGTH' => '4',
          'HTTP_X_AMZ_ACL' => 'public-read-write',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, 'abcd', headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
      end

      it 'full_control is added to owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'read and write are added to guest' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should == [S3Adapter::Acl::READ, S3Adapter::Acl::WRITE]
      end
    end

    context 'authenticated-read given x-amz-acl header' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time.httpdate,
          'CONTENT_LENGTH' => '4',
          'HTTP_X_AMZ_ACL' => 'authenticated-read',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, 'abcd', headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
      end

      it 'full_control is added to owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'read is added to authenticated' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should == [S3Adapter::Acl::READ]
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

    context 'bucket-owner-read given x-amz-acl header' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time.httpdate,
          'CONTENT_LENGTH' => '4',
          'HTTP_X_AMZ_ACL' => 'bucket-owner-read',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, 'abcd', headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 2
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should_not be_nil
      end

      it 'full_control is added to owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'read is added to bucket owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::READ]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

    context 'bucket-owner-full-control given x-amz-acl header' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time.httpdate,
          'CONTENT_LENGTH' => '4',
          'HTTP_X_AMZ_ACL' => 'bucket-owner-full-control',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, 'abcd', headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 2
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should_not be_nil
      end

      it 'full_control is added to owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'full_control is added to bucket owner.' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

  end

  describe 'access which is not permitted' do
    context 'given not permitted bucket' do
      before(:all) do
        @user = 'test_user1'
        @path = '/no_set_acl/foo/bar/baz.txt'
        headers = {
          'HTTP_DATE'      => @time.httpdate,
          'CONTENT_LENGTH' => '4',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, 'abcd', headers
      end

      it 'should return response code 403' do
        last_response.status.should == 403
      end

      it 'should return response headers' do
        last_response.header['server'].should == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return access denied response' do
        xml = REXML::Document.new last_response.body
        xml.elements['Error/Code'].text.should    == 'AccessDenied'
        xml.elements['Error/Message'].text.should == 'Access Denied'
        xml.elements['Error/RequestId'].text.should == nil
        xml.elements['Error/HostId'].text.should == nil
      end
    end
  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
