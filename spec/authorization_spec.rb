
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'Authorization Header' do
  include Rack::Test::Methods

  before(:all) do
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
  end

  before(:each) do # mock cannot be used by before(:all).
    S3Adapter::DependencyInjector.stub!(:time_now).with(no_args).and_return { Time.parse("2011-08-25T16:14:09Z") }
  end

  context 'given valid authorization header.' do
    before(:each) do
      @user = 'test_user1'
      headers = { "HTTP_DATE" => "Fri, 26 Aug 2011 01:14:09 +0900" }
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      get "/", {}, headers
    end

    it 'should return response code 200.' do
      last_response.should be_ok
    end
  end

  context 'given "AWS " not included in authorization header.' do
    before(:all) do
      @user = 'test_user1'
      headers = {}
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
      headers['HTTP_AUTHORIZATION'] = "#{@users[@user]['access-key-id']}:#{signature}"
      get "/", {}, headers
    end

    it 'should return response code 400.' do
      last_response.status.should == 400
    end

    it 'should return response headers.' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return InvalidAccessKeyId response body.' do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should == "InvalidArgument"
      xml.elements["Error/Message"].text.should == "Authorization header is invalid -- one and only one ' ' (space) required"
      xml.elements["Error/ArgumentValue"].text.should == "XXXXXXXXXXXXXXXXXXXX:4oOoZDnSHAs6lZPAcAPp+X8/EmM="
      xml.elements["Error/ArgumentName"].text.should == "Authorization"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context 'given valid authorization header value added "::::".' do
    before(:each) do
      @user = 'test_user1'
      headers = { "HTTP_DATE" => "Fri, 26 Aug 2011 01:14:09 +0900" }
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}:::::::::"
      get "/", {}, headers
    end

    it 'should return response code 200.' do
      last_response.should be_ok
    end
  end

  context 'given invalid authorization header value added ":hoge".' do
    before(:all) do
      @user = 'test_user1'
      headers = {}
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}:hoge"
      get "/", {}, headers
    end

    it 'should return response code 400.' do
      last_response.status.should == 400
    end

    it 'should return response headers.' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return InvalidAccessKeyId response body.' do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should == "InvalidArgument"
      xml.elements["Error/Message"].text.should == "AWS authorization header is invalid.  Expected AwsAccessKeyId:signature"
      xml.elements["Error/ArgumentValue"].text.should == "AWS XXXXXXXXXXXXXXXXXXXX:4oOoZDnSHAs6lZPAcAPp+X8/EmM=:hoge"
      xml.elements["Error/ArgumentName"].text.should == "Authorization"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context 'given invalid access_key_id of authorization header.' do
    before(:all) do
      @user = 'test_user1'
      headers = {}
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
      headers['HTTP_AUTHORIZATION'] = "AWS invalid_access_key_id:#{signature}"
      get "/", {}, headers
    end

    it 'should return response code 403.' do
      last_response.status.should == 403
    end

    it 'should return response headers.' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return InvalidAccessKeyId response body.' do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should == "InvalidAccessKeyId"
      xml.elements["Error/Message"].text.should == "The AWS Access Key Id you provided does not exist in our records."
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
      xml.elements["Error/AWSAccessKeyId"].text.should == "invalid_access_key_id"
    end
  end

  context 'given invalid secret_access_key of authorization header.' do
    before(:each) do
      @user = 'test_user1'
      headers = {}
      @signature = aws_signature("invalid_secret_access_key", 'GET', "/", headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{@signature}"
      get "/", {}, headers
    end

    it 'should return response code 403.' do
      last_response.status.should == 403
    end

    it 'should return response headers.' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return SignatureDoesNotMatch response body.' do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should == "SignatureDoesNotMatch"
      xml.elements["Error/Message"].text.should == "The request signature we calculated does not match the signature you provided. Check your key and signing method."
      xml.elements["Error/StringToSignBytes"].text.should == "47 45 54 0a 0a 0a 0a 2f"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
      xml.elements["Error/SignatureProvided"].text.should == @signature
      xml.elements["Error/StringToSign"].text.should == "GET\n\n\n\n/"
      xml.elements["Error/AWSAccessKeyId"].text.should == "XXXXXXXXXXXXXXXXXXXX"
    end
  end

  describe "Date header and x-amz-date header." do
    context 'no given date and x-amz-date header.' do
      before(:all) do
        @user = 'test_user1'
        headers = {}
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 403.' do
        last_response.status.should == 403
      end

      it 'should return response headers.' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessDenied response body.' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "AccessDenied"
        xml.elements["Error/Message"].text.should == "AWS authentication requires a valid Date or x-amz-date header"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'given valid date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = { "HTTP_DATE" => "Fri, 26 Aug 2011 01:14:09 +0900" }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 200.' do
        last_response.should be_ok
      end
     end

    context 'given valid x-amz-date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = { "HTTP_X_AMZ_DATE" => "Fri, 26 Aug 2011 01:14:09 +0900" }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 200.' do
        last_response.should be_ok
      end
    end

    context 'given invalid format date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = { "HTTP_DATE" => "2011082601:14:09" }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 403.' do
        last_response.status.should == 403
      end

      it 'should return response headers.' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessDenied response body.' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "AccessDenied"
        xml.elements["Error/Message"].text.should == "AWS authentication requires a valid Date or x-amz-date header"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'given invalid format x-amz-date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = { "HTTP_X_AMZ_DATE" => "2011082601:14:09" }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 403.' do
        last_response.status.should == 403
      end

      it 'should return response headers.' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessDenied response body.' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "AccessDenied"
        xml.elements["Error/Message"].text.should == "AWS authentication requires a valid Date or x-amz-date header"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'given invalid format date and valid x-amz-date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = {
          "HTTP_DATE" => "2011082601:14:09",
          "HTTP_X_AMZ_DATE" => "Fri, 26 Aug 2011 01:14:09 +0900"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 200.' do
        last_response.should be_ok
      end
    end

    context 'given valid format date header and invalid x-amz-date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = {
          "HTTP_DATE" => "Fri, 26 Aug 2011 01:14:09 +0900",
          "HTTP_X_AMZ_DATE" => "2011082601:14:09"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 403.' do
        last_response.status.should == 403
      end

      it 'should return response headers.' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessDenied response body.' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "AccessDenied"
        xml.elements["Error/Message"].text.should == "AWS authentication requires a valid Date or x-amz-date header"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'given too skewed timestamp data header. (time lag > 15 minutes)' do
      before(:each) do
        @user = 'test_user1'
        headers = { "HTTP_DATE" => "Fri, 26 Aug 2011 20:14:09 +0900" }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 403.' do
        last_response.status.should == 403
      end

      it 'should return response headers.' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return RequestTimeTooSkewed response body.' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "RequestTimeTooSkewed"
        xml.elements["Error/Message"].text.should == "The difference between the request time and the current time is too large."
        xml.elements["Error/MaxAllowedSkewMilliseconds"].text.should == "900000"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
        xml.elements["Error/RequestTime"].text.should == "Fri, 26 Aug 2011 20:14:09 +0900"
        xml.elements["Error/ServerTime"].text.should == "2011-08-25T16:14:09Z"
      end
    end

    context 'given too skewed timestamp x-amz-date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = { "HTTP_X_AMZ_DATE" => "Fri, 26 Aug 2011 20:14:09 +0900" }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 403.' do
        last_response.status.should == 403
      end

      it 'should return response headers.' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return RequestTimeTooSkewed response body.' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "RequestTimeTooSkewed"
        xml.elements["Error/Message"].text.should == "The difference between the request time and the current time is too large."
        xml.elements["Error/MaxAllowedSkewMilliseconds"].text.should == "900000"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
        xml.elements["Error/RequestTime"].text.should == "Fri, 26 Aug 2011 20:14:09 +0900"
        xml.elements["Error/ServerTime"].text.should == "2011-08-25T16:14:09Z"
      end
    end

    context 'given too skewed timestamp data header and valid x-amz-date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = {
          "HTTP_DATE" => "Fri, 26 Aug 2011 20:14:09 +0900",
          "HTTP_X_AMZ_DATE" => "Fri, 26 Aug 2011 01:14:09 +0900"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 200.' do
        last_response.should be_ok
      end
    end

    context 'given valid date header and too skewed timestamp x-amz-date header.' do
      before(:each) do
        @user = 'test_user1'
        headers = {
          "HTTP_DATE" => "Fri, 26 Aug 2011 01:14:09 +0900",
          "HTTP_X_AMZ_DATE" => "Fri, 26 Aug 2011 20:14:09 +0900"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', "/", headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get "/", {}, headers
      end

      it 'should return response code 403.' do
        last_response.status.should == 403
      end

      it 'should return response headers.' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return RequestTimeTooSkewed response body.' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "RequestTimeTooSkewed"
        xml.elements["Error/Message"].text.should == "The difference between the request time and the current time is too large."
        xml.elements["Error/MaxAllowedSkewMilliseconds"].text.should == "900000"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
        xml.elements["Error/RequestTime"].text.should == "Fri, 26 Aug 2011 20:14:09 +0900"
        xml.elements["Error/ServerTime"].text.should == "2011-08-25T16:14:09Z"
      end
    end

  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
