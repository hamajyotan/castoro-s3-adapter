
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'GET Bucket acl' do
  include Rack::Test::Methods

  before(:all) do
    @users = {
      # bucket owner.
      'test_user1' => {
        'access-key-id' => 'XXXXXXXXXXXXXXXXXXXX',
        'secret-access-key' => 'AStringOfSecretAccessKey',
      },
      # set acl user.
      'test_user2' => {
        'access-key-id' => 'AStringOfAccessKeyId',
        'secret-access-key' => 'VeryVeryVerySecretAccessKey',
      },
      # no set acl user.
      'test_user3' => {
        'access-key-id' => 'NoSetACLAccessKeyId',
        'secret-access-key' => 'NoSetACLUserSecretAccessKey',
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

    @time = Time.now.httpdate
  end

  before(:each) do # mock cannot be used by before(:all).
    @time_mock = mock(Time)
    S3Adapter::DependencyInjector.stub!(:time_now).with(no_args).and_return { @time_mock }
    @time_mock.stub!(:utc).and_return { @time_mock }
    @time_mock.stub!(:iso8601).and_return { '2011-08-26T01:14:09Z' }
  end

  describe "no acl bucket." do
    context 'Bucket owner request.' do
      before(:all) do
        @user = 'test_user3'
        headers = {
          "HTTP_DATE" => @time,
          "HTTP_HOST" => "no_set_acl.s3.adapter"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/?acl', headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "NoSetACLAccessKeyId"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user3"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[0]"].should be_nil
      end
    end

    context 'Authenticated user request.' do
      before(:all) do
        @user = 'test_user2'
        headers = {
          "HTTP_DATE" => @time,
          "HTTP_HOST" => "no_set_acl.s3.adapter"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/?acl', headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get '/?acl', {}, headers
      end

      it 'should return response code 403' do
        last_response.status.should == 403
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessDenied response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "AccessDenied"
        xml.elements["Error/Message"].text.should == "Access Denied"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'Anonymous user request.' do
      before(:all) do
        headers = { "HTTP_HOST" => "no_set_acl.s3.adapter" }
        get '/?acl', {}, headers
      end

      it 'should return response code 403' do
        last_response.status.should == 403
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessDenied response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "AccessDenied"
        xml.elements["Error/Message"].text.should == "Access Denied"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

  end

  describe "set acl bucket(WRITE | READ | WRITE_ACP | READ_ACP)." do
    context 'Bucket owner request.' do
      before(:all) do
        @user = 'test_user1'
        headers = {
          "HTTP_DATE" => @time,
          "HTTP_HOST" => "castoro.s3.adapter"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/castoro/?acl', headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "XXXXXXXXXXXXXXXXXXXX"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[17]"].should be_nil
      end
    end

    context 'Canonical user request.' do
      before(:all) do
        @user = 'test_user2'
        headers = {
          "HTTP_DATE" => @time,
          "HTTP_HOST" => "castoro.s3.adapter"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/castoro/?acl', headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "XXXXXXXXXXXXXXXXXXXX"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[17]"].should be_nil
      end
    end

    context 'Authenticated user request.' do
      before(:all) do
        @user = 'test_user3'
        headers = {
          "HTTP_DATE" => @time,
          "HTTP_HOST" => "castoro.s3.adapter"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/castoro/?acl', headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "XXXXXXXXXXXXXXXXXXXX"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[17]"].should be_nil
      end
    end

    context 'Anonymous user request.' do
      before(:all) do
        headers = { "HTTP_HOST" => "castoro.s3.adapter" }
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "XXXXXXXXXXXXXXXXXXXX"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[6]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[7]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[8]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[9]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[10]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[11]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[12]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[13]/Permission"].text.should == "READ"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[14]/Permission"].text.should == "WRITE"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[15]/Permission"].text.should == "READ_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[16]/Permission"].text.should == "WRITE_ACP"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[17]"].should be_nil
      end
    end

  end

  describe "set acl bucket(FULL_CONTROL)." do
    context 'Bucket owner request.' do
      before(:all) do
        @user = 'test_user1'
        headers = {
          "HTTP_DATE" => @time,
          "HTTP_HOST" => "test.s3.adapter"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/?acl', headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "AStringOfAccessKeyId"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]"].should be_nil
      end
    end

    context 'Canonical user request.' do
      before(:all) do
        @user = 'test_user2'
        headers = {
          "HTTP_DATE" => @time,
          "HTTP_HOST" => "test.s3.adapter"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/?acl', headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "AStringOfAccessKeyId"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[5]"].should be_nil
      end
    end

    context 'Authenticated user request.' do
      before(:all) do
        @user = 'test_user3'
        headers = {
          "HTTP_DATE" => @time,
          "HTTP_HOST" => "test.s3.adapter"
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/?acl', headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "AStringOfAccessKeyId"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Permission"].text.should == "FULL_CONTROL"
      end
    end

    context 'Anonymous user request.' do
      before(:all) do
        headers = { "HTTP_HOST" => "test.s3.adapter" }
        get '/?acl', {}, headers
      end

      it 'should return response code 200' do
        last_response.should be_ok
      end

      it 'should return response headers' do
        last_response.header['server'].should       == 'AmazonS3'
        last_response.header['content-type'].should == 'application/xml;charset=utf-8'
      end

      it 'should return AccessControlPolicy response body' do
        xml = REXML::Document.new last_response.body
        xml.elements["AccessControlPolicy/Owner/ID"].text.should == "AStringOfAccessKeyId"
        xml.elements["AccessControlPolicy/Owner/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/ID"].text.should == @users["test_user1"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Grantee/DisplayName"].text.should == "test_user1"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[1]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee"].attributes["xsi:type"].should == "CanonicalUser"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/ID"].text.should == @users["test_user2"]['access-key-id']
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Grantee/DisplayName"].text.should == "test_user2"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[2]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[3]/Permission"].text.should == "FULL_CONTROL"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee"].attributes["xsi:type"].should == "Group"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Grantee/URI"].text.should == "http://acs.amazonaws.com/groups/global/AllUsers"
        xml.elements["AccessControlPolicy/AccessControlList/Grant[4]/Permission"].text.should == "FULL_CONTROL"
      end
    end

  end
end
