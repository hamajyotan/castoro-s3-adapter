
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'

describe 'GET Object acl' do
  include Rack::Test::Methods

  before(:all) do

    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
    FileUtils.mkdir_p S3Adapter::Adapter::BASE

    Castoro::Client.new() { |c|
      c.create("1.1000.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "abcd" }
      }
      c.create("2.1000.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("3.1000.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("4.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "abcd" }
      }
      c.create("5.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("6.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
    }

    @users = {
      # set acl user(READ | WRITE | READ_ACP | WRITE_ACP).
      'test_user1' => {
        'access-key-id' => 'XXXXXXXXXXXXXXXXXXXX',
        'secret-access-key' => 'AStringOfSecretAccessKey',
      },
      # set acl user(FULL_CONTROL).
      'test_user2' => {
        'access-key-id' => 'AStringOfAccessKeyId',
        'secret-access-key' => 'VeryVeryVerySecretAccessKey',
      },
      # no acl user.
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

    S3Object.delete_all
    # set acl bucket object, bucket acl is "FULL_CONTROL".
    # no acl object.
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "foo/bar/baz.txt"
      o.id               = 1
      o.basket_rev       = 1
      o.last_modified    = "2011-07-21T19:14:36+09:00"
      o.etag             = "ea703e7aa1efda0064eaa507d9e8ab7e"
      o.size             = 4
      o.content_type     = "application/octet-stream"
      o.owner_access_key = "NoSetACLAccessKeyId"
      o.save
    }
    # set acl object(READ | WRITE | READ_ACP | WRITE_ACP).
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "hoge/fuga/piyo.txt"
      o.id               = 2
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "XXXXXXXXXXXXXXXXXXXX"
      o.acl              = {
        'account' => {
          'XXXXXXXXXXXXXXXXXXXX' => ["READ", "WRITE", "READ_ACP", "WRITE_ACP"],
          'AStringOfAccessKeyId' => ["READ", "WRITE", "READ_ACP", "WRITE_ACP"],
        },
        'authenticated' => ["READ", "WRITE", "READ_ACP", "WRITE_ACP"],
        'guest' => ["READ", "WRITE", "READ_ACP", "WRITE_ACP"],
      }
      o.save
    }
    # set acl object(FULL_CONTROL).
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "full_control.txt"
      o.id               = 3
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "AStringOfAccessKeyId"
      o.acl              = {
        'account' => {
          'XXXXXXXXXXXXXXXXXXXX' => ["FULL_CONTROL"],
          'AStringOfAccessKeyId' => ["FULL_CONTROL"],
        },
        'authenticated' => ["FULL_CONTROL"],
        'guest' => ['FULL_CONTROL'],
      }
      o.save
    }
    # no acl bucket object.
    # no acl object.
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "foo/bar/baz.txt"
      o.id               = 4
      o.basket_rev       = 1
      o.last_modified    = "2011-07-21T19:14:36+09:00"
      o.etag             = "ea703e7aa1efda0064eaa507d9e8ab7e"
      o.size             = 4
      o.content_type     = "application/octet-stream"
      o.owner_access_key = "NoSetACLAccessKeyId"
      o.save
    }
    # set acl object(READ | WRITE | READ_ACP | WRITE_ACP).
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "hoge/fuga/piyo.txt"
      o.id               = 5
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "XXXXXXXXXXXXXXXXXXXX"
      o.acl              = {
        'account' => {
          'XXXXXXXXXXXXXXXXXXXX' => ["READ", "WRITE", "READ_ACP", "WRITE_ACP"],
          'AStringOfAccessKeyId' => ["READ", "WRITE", "READ_ACP", "WRITE_ACP"],
        },
        'authenticated' => ["READ", "WRITE", "READ_ACP", "WRITE_ACP"],
        'guest' => ["READ", "WRITE", "READ_ACP", "WRITE_ACP"],
      }
      o.save
    }
    # set acl object(FULL_CONTROL).
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "full_control.txt"
      o.id               = 6
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "AStringOfAccessKeyId"
      o.acl              = {
        'account' => {
          'XXXXXXXXXXXXXXXXXXXX' => ["FULL_CONTROL"],
          'AStringOfAccessKeyId' => ["FULL_CONTROL"],
        },
        'authenticated' => ["FULL_CONTROL"],
        'guest' => ['FULL_CONTROL'],
      }
      o.save
    }

    @time = Time.now.httpdate
  end

  before(:each) do # mock cannot be used by before(:all).
    @time_mock = mock(Time)
    S3Adapter::DependencyInjector.stub!(:time_now).with(no_args).and_return { @time_mock }
    @time_mock.stub!(:utc).and_return { @time_mock }
    @time_mock.stub!(:iso8601).and_return { '2011-08-26T01:14:09Z' }
  end

  context "given invalid bucketname" do
    before(:all) do
      @user = 'test_user1'
      path = "/hoge/foo/bar/baz.txt?acl"
      headers = { "HTTP_DATE" => @time }
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      get path, {}, headers
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return response header." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
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
      @user = 'test_user1'
      path = "/castoro/foo/foo/foo.txt?acl"
      headers = { "HTTP_DATE" => @time }
      signature = aws_signature(@users[@user]['secret-access-key'], 'GET', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      get path, {}, headers
    end

    it "should return response code 404." do
      last_response.should be_not_found
    end

    it "should return response header." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return NoSuchKey response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should    == "NoSuchKey"
      xml.elements["Error/Message"].text.should == "The specified key does not exist."
      xml.elements["Error/Key"].text.should     == "foo/foo/foo.txt"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  describe "no acl Bucket." do
    describe "no acl Object." do
      context 'Object owner request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/foo/bar/baz.txt?acl', {}, headers
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
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/foo/bar/baz.txt?acl', {}, headers
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
          get '/foo/bar/baz.txt?acl', {}, headers
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

    describe "set acl Object(WRITE | READ | WRITE_ACP | READ_ACP)." do
      context 'Object owner request.' do
        before(:all) do
          @user = 'test_user1'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/hoge/fuga/piyo.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/hoge/fuga/piyo.txt?acl', {}, headers
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
            "HTTP_HOST" => "no_set_acl.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/hoge/fuga/piyo.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/hoge/fuga/piyo.txt?acl', {}, headers
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
            "HTTP_HOST" => "no_set_acl.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/hoge/fuga/piyo.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/hoge/fuga/piyo.txt?acl', {}, headers
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
          headers = { "HTTP_HOST" => "no_set_acl.s3.adapter" }
          get '/hoge/fuga/piyo.txt?acl', {}, headers
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
  
    describe "set acl Object(FULL_CONTROL)." do
      context 'Object owner request.' do
        before(:all) do
          @user = 'test_user2'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/full_control.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/full_control.txt?acl', {}, headers
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
          @user = 'test_user1'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/full_control.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/full_control.txt?acl', {}, headers
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
            "HTTP_HOST" => "no_set_acl.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/no_set_acl/full_control.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/full_control.txt?acl', {}, headers
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
  
      context 'Anonymous user request.' do
        before(:all) do
          headers = { "HTTP_HOST" => "no_set_acl.s3.adapter" }
          get '/full_control.txt?acl', {}, headers
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
    end
  end

  describe "set acl Bucket." do
    describe "no acl Object." do
      context 'Object owner request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/foo/bar/baz.txt?acl', {}, headers
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
            "HTTP_HOST" => "test.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/foo/bar/baz.txt?acl', {}, headers
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
          headers = { "HTTP_HOST" => "test.s3.adapter" }
          get '/foo/bar/baz.txt?acl', {}, headers
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
  
    describe "set acl Object(WRITE | READ | WRITE_ACP | READ_ACP)." do
      context 'Object owner request.' do
        before(:all) do
          @user = 'test_user1'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/hoge/fuga/piyo.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/hoge/fuga/piyo.txt?acl', {}, headers
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
            "HTTP_HOST" => "test.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/hoge/fuga/piyo.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/hoge/fuga/piyo.txt?acl', {}, headers
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
            "HTTP_HOST" => "test.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/hoge/fuga/piyo.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/hoge/fuga/piyo.txt?acl', {}, headers
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
          headers = { "HTTP_HOST" => "test.s3.adapter" }
          get '/hoge/fuga/piyo.txt?acl', {}, headers
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
  
    describe "set acl Object(FULL_CONTROL)." do
      context 'Object owner request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/full_control.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/full_control.txt?acl', {}, headers
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
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/full_control.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/full_control.txt?acl', {}, headers
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
          @user = 'test_user1'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter"
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'GET', '/test/full_control.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          get '/full_control.txt?acl', {}, headers
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
  
      context 'Anonymous user request.' do
        before(:all) do
          headers = { "HTTP_HOST" => "test.s3.adapter" }
          get '/full_control.txt?acl', {}, headers
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
    end
  end
end
