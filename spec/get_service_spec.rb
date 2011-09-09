
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'GET Service' do
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
      'test_user3' => {
        'access-key-id' => 'HogeFugaPiyoHogeFuga',
        'secret-access-key' => 'FooBarBazQuxQuuxQuuuxQuuuux',
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
    @time = Time.now
  end

  before(:each) do # mock cannot be used by before(:all).
    @time_mock = mock(Time)
    S3Adapter::DependencyInjector.stub!(:time_now).with(no_args).and_return { @time_mock }
    @time_mock.stub!(:utc).and_return { @time.utc }
    @time_mock.stub!(:iso8601).and_return { @time.iso8601 }
  end

  context 'not given authorization header' do
    before(:all) do
      get '/', {}
    end

    it 'should return code 307' do
      last_response.status.should == 307
    end

    it 'should included location header' do
      last_response.header['location'].should == 'http://aws.amazon.com/s3'
    end

    it 'should return empty body' do
      last_response.body.should == ''
    end
  end

  context 'given invalid access_key_id of authorization header' do
    before(:all) do
      @user = 'test_user1'
      headers = {}
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/', headers)
      headers['HTTP_AUTHORIZATION'] = "AWS invalid_access_key_id:#{signature}"
      get '/', {}, headers
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
    before(:all) do
      @user = 'test_user1'
      headers = {}
      @signature = aws_signature("invalid_secret_access_key", 'GET', '/', headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{@signature}"
      get '/', {}, headers
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
      xml.elements["Error/StringToSignBytes"].text.should == "47 45 54 0a 0a 0a 0a 2f"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
      xml.elements["Error/SignatureProvided"].text.should == @signature
      xml.elements["Error/StringToSign"].text.should == "GET\n\n\n\n/"
      xml.elements["Error/AWSAccessKeyId"].text.should == "XXXXXXXXXXXXXXXXXXXX"
    end
  end

  context 'given test_user1 authorization header' do
    before(:each) do # mock cannot be used by before(:all).
      @user = 'test_user1'
      headers = { "HTTP_DATE" => @time.httpdate }
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/', headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      get '/', {}, headers
    end

    it 'should return code 200' do
      last_response.should be_ok
    end

    it 'should return response headers' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return owned bucket list' do
      xml = REXML::Document.new last_response.body
      xml.elements['ListAllMyBucketsResult/Owner/ID'].text.should == @users[@user]['access-key-id']
      xml.elements['ListAllMyBucketsResult/Owner/DisplayName'].text.should == @user
      xml.elements['ListAllMyBucketsResult/Buckets/Bucket[1]/Name'].text.should == 'castoro'
      xml.elements['ListAllMyBucketsResult/Buckets/Bucket[1]/CreationDate'].text.should == @time_mock.utc.iso8601
      xml.elements['ListAllMyBucketsResult/Buckets/Bucket[2]'].should be_nil
    end
  end

  context 'given test_user2 authorization header' do
    before(:each) do # mock cannot be used by before(:all).
      @user = 'test_user2'
      headers = { "HTTP_DATE" => @time.httpdate }
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/', headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      get '/', {}, headers
    end

    it 'should return code 200' do
      last_response.should be_ok
    end

    it 'should return response headers' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return owned bucket list' do
      xml = REXML::Document.new last_response.body
      xml.elements['ListAllMyBucketsResult/Owner/ID'].text.should == @users[@user]['access-key-id']
      xml.elements['ListAllMyBucketsResult/Owner/DisplayName'].text.should == @user
      xml.elements['ListAllMyBucketsResult/Buckets/Bucket[1]/Name'].text.should == 'test'
      xml.elements['ListAllMyBucketsResult/Buckets/Bucket[1]/CreationDate'].text.should == @time_mock.utc.iso8601
      xml.elements['ListAllMyBucketsResult/Buckets/Bucket[2]'].should be_nil
    end
  end

  context 'given test_user3 authorization header' do
    before(:all) do
      @user = 'test_user3'
      headers = { "HTTP_DATE" => @time.httpdate }
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/', headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      get '/', {}, headers
    end

    it 'should return code 200' do
      last_response.should be_ok
    end

    it 'should return response headers' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it 'should return owned bucket list' do
      xml = REXML::Document.new last_response.body
      xml.elements['ListAllMyBucketsResult/Owner/ID'].text.should == @users[@user]['access-key-id']
      xml.elements['ListAllMyBucketsResult/Owner/DisplayName'].text.should == @user
      xml.elements['ListAllMyBucketsResult/Buckets/Bucket[1]'].should be_nil
    end
  end

end

