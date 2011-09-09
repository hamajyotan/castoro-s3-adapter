
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
      o.save
    }
  end

  before(:each) do # mock cannot be used by before(:all).
    @time_mock = mock(Time)
    S3Adapter::DependencyInjector.stub!(:time_now).with(no_args).and_return { @time_mock }
    @time_mock.stub!(:utc).and_return { @time_mock }
    @time_mock.stub!(:iso8601).and_return { '2011-08-26T01:14:09Z' }
  end

 context 'given invalid access_key_id of authorization header' do
   before(:all) do
     @user = 'test_user1'
     path = "/castoro/foo/bar/baz.txt"
     headers = {}
     signature = aws_signature(@users[@user]['secret-access-key'], 'DELETE', path, headers)
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
      @signature = aws_signature("invalid_secret_access_key", 'DELETE', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{@signature}"
      delete path, {}, headers
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
      xml.elements["Error/StringToSignBytes"].text.should == "44 45 4c 45 54 45 0a 0a 0a 0a 2f 63 61 73 74 6f 72 6f 2f 66 6f 6f 2f 62 61 72 2f 62 61 7a 2e 74 78 74"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
      xml.elements["Error/SignatureProvided"].text.should == @signature
      xml.elements["Error/StringToSign"].text.should == "DELETE\n\n\n\n/castoro/foo/bar/baz.txt"
      xml.elements["Error/AWSAccessKeyId"].text.should == "XXXXXXXXXXXXXXXXXXXX"
    end
  end

  context "given valid bucketname and objectkey(foo/bar/baz.txt)" do
    before(:all) do
      @obj = find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj| obj }
      delete "/castoro/foo/bar/baz.txt"
    end

    it "should return response code 204." do
      last_response.status.should == 204
    end

    it "should return response headers" do
      last_response.header["server"].should == "AmazonS3"
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end

    it "should exist object record." do
      find_by_bucket_and_path('castoro', 'foo/bar/baz.txt') { |obj|
        obj.basket_type.should      == @obj.basket_type
        obj.path.should             == @obj.path
        obj.basket_rev.should       == @obj.basket_rev + 1
        obj.last_modified.should    == @obj.last_modified
        obj.etag.should             == @obj.etag
        obj.size.should             == @obj.size
        obj.content_type.should     == @obj.content_type
        obj.owner_access_key.should == @obj.owner_access_key
        obj.deleted.should be_true
      }
    end
  end

  context "given valid bucketname and objectkey(hoge/fuga/piyo.txt)" do
    before(:all) do
      @obj = find_by_bucket_and_path('castoro', 'hoge/fuga/piyo.txt') { |obj| obj }
      delete "/castoro/hoge/fuga/piyo.txt"
    end

    it "should return response code 204." do
      last_response.status.should == 204
    end

    it "should return response headers" do
      last_response.header["server"].should == "AmazonS3"
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end

    it "should exist object record." do
      find_by_bucket_and_path('castoro', 'hoge/fuga/piyo.txt') { |obj|
        obj.basket_type.should      == @obj.basket_type
        obj.path.should             == @obj.path
        obj.basket_rev.should       == @obj.basket_rev + 1
        obj.last_modified.should    == @obj.last_modified
        obj.etag.should             == @obj.etag
        obj.size.should             == @obj.size
        obj.content_type.should     == @obj.content_type
        obj.owner_access_key.should == @obj.owner_access_key
        obj.deleted.should be_true
      }
    end
  end

  context "given invalid bucketname" do
    before(:all) do
      delete "/hoge/foo/bar/baz.txt"
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return response headers" do
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
      delete "/castoro/foo/foo/foo.txt"
    end

    it "should return response code 204." do
      last_response.status.should == 204
    end

    it "should return response headers" do
      last_response.header["server"].should == "AmazonS3"
    end

    it "should return no response body." do
      last_response.body.should be_empty
    end
  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
