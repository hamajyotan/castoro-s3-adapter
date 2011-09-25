
require File.expand_path('../../spec/spec_helper', __FILE__)

require 'time'
require 'net/http'
require 'rexml/document'
require 'base64'
require 'digest'

describe 'PUT Object acl' do
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
      c.create("4.1000.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("5.1000.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("6.1000.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("7.1000.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("8.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "abcd" }
      }
      c.create("9.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("10.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("11.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("12.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("13.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
      c.create("14.1001.1") { |host, path|
        path = File.join(S3Adapter::Adapter::BASE, host, path, S3Adapter::Adapter::S3ADAPTER_FILE)
        File.open(path, "w") { |f| f.write "01234567" }
      }
    }

    @users = {
      # set acl user(WRITE_ACP).
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
    # set acl object(WRITE_ACP).
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
          'XXXXXXXXXXXXXXXXXXXX' => ["WRITE_ACP"],
          'AStringOfAccessKeyId' => ["WRITE_ACP"],
        },
        'authenticated' => ["WRITE_ACP"],
        'guest' => ["WRITE_ACP"],
      }
      o.save
    }
    # set acl specific user bject(WRITE_ACP).
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "specific_user_object_acl"
      o.id               = 3
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "XXXXXXXXXXXXXXXXXXXX"
      o.acl              = {
        'account' => {
          'AStringOfAccessKeyId' => ["WRITE_ACP"],
        },
      }
      o.save
    }
    # set acl authenticated user bject(WRITE_ACP).
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "authenticated_user_object_acl"
      o.id               = 4
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "XXXXXXXXXXXXXXXXXXXX"
      o.acl              = {
        'authenticated' => ["WRITE_ACP"],
      }
      o.save
    }
    # set acl specific user object(FULL_CONTROL).
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "specfic_user_full_control"
      o.id               = 5
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "AStringOfAccessKeyId"
      o.acl              = {
        'account' => {
          'XXXXXXXXXXXXXXXXXXXX' => ["FULL_CONTROL"],
        },
      }
      o.save
    }
    # set acl authenticated user object(FULL_CONTROL).
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "authenticated_user_full_control_acl"
      o.id               = 6
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "AStringOfAccessKeyId"
      o.acl              = {
        'authenticated' => ["FULL_CONTROL"],
      }
      o.save
    }
    # set acl object(FULL_CONTROL).
    S3Object.new { |o|
      o.basket_type      = 1000
      o.path             = "full_control.txt"
      o.id               = 7
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
      o.id               = 8
      o.basket_rev       = 1
      o.last_modified    = "2011-07-21T19:14:36+09:00"
      o.etag             = "ea703e7aa1efda0064eaa507d9e8ab7e"
      o.size             = 4
      o.content_type     = "application/octet-stream"
      o.owner_access_key = "NoSetACLAccessKeyId"
      o.save
    }
    # set acl object(WRITE_ACP).
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "hoge/fuga/piyo.txt"
      o.id               = 9
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "XXXXXXXXXXXXXXXXXXXX"
      o.acl              = {
        'account' => {
          'XXXXXXXXXXXXXXXXXXXX' => ["WRITE_ACP"],
          'AStringOfAccessKeyId' => ["WRITE_ACP"],
        },
        'authenticated' => ["WRITE_ACP"],
        'guest' => ["WRITE_ACP"],
      }
      o.save
    }
    # set acl specific user object(WRITE_ACP).
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "specific_user_object"
      o.id               = 10
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "XXXXXXXXXXXXXXXXXXXX"
      o.acl              = {
        'account' => {
          'AStringOfAccessKeyId' => ["WRITE_ACP"],
        },
      }
      o.save
    }
    # set acl authenticated user object(WRITE_ACP).
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "authenticated_user_object"
      o.id               = 11
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "XXXXXXXXXXXXXXXXXXXX"
      o.acl              = {
        'authenticated' => ["WRITE_ACP"],
      }
      o.save
    }
    # set acl object(FULL_CONTROL).
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "full_control.txt"
      o.id               = 12
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
    # set acl specific user object(FULL_CONTROL).
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "specfic_user_full_control"
      o.id               = 13
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
      }
      o.save
    }
    # set acl authenticated user object(FULL_CONTROL).
    S3Object.new { |o|
      o.basket_type      = 1001
      o.path             = "authenticated_user_full_control"
      o.id               = 14
      o.basket_rev       = 1
      o.last_modified    = "2011-05-13T14:43:24+09:00"
      o.etag             = "02ccdb34c1f7a8c84b72e003ddd77173"
      o.size             = 8
      o.content_type     = "text/plain"
      o.owner_access_key = "AStringOfAccessKeyId"
      o.acl              = {
        'authenticated' => ["FULL_CONTROL"],
      }
      o.save
    }

    @time = Time.now.httpdate
    @acl_list = {}
    @acl_list['test_user1'] = <<END_OF_ACL
<AccessControlPolicy>
  <Owner>
    <ID>XXXXXXXXXXXXXXXXXXXX</ID>
    <DisplayName>test_user1</DisplayName>
  </Owner>
  <AccessControlList>
    <Grant>
      <Grantee xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="CanonicalUser">
        <ID>XXXXXXXXXXXXXXXXXXXX</ID>
        <DisplayName>test_user1</DisplayName>
      </Grantee>
      <Permission>FULL_CONTROL</Permission>
    </Grant>
  </AccessControlList>
</AccessControlPolicy>
END_OF_ACL
    @acl_list['test_user2'] = <<END_OF_ACL
<AccessControlPolicy>
  <Owner>
    <ID>AStringOfAccessKeyId</ID>
    <DisplayName>test_user2</DisplayName>
  </Owner>
  <AccessControlList>
    <Grant>
      <Grantee xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="CanonicalUser">
        <ID>XXXXXXXXXXXXXXXXXXXX</ID>
        <DisplayName>test_user1</DisplayName>
      </Grantee>
      <Permission>FULL_CONTROL</Permission>
    </Grant>
  </AccessControlList>
</AccessControlPolicy>
END_OF_ACL
    @acl_list['test_user3'] = <<END_OF_ACL
<AccessControlPolicy>
  <Owner>
    <ID>NoSetACLAccessKeyId</ID>
    <DisplayName>test_user3</DisplayName>
  </Owner>
  <AccessControlList>
    <Grant>
      <Grantee xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="CanonicalUser">
        <ID>XXXXXXXXXXXXXXXXXXXX</ID>
        <DisplayName>test_user1</DisplayName>
      </Grantee>
      <Permission>FULL_CONTROL</Permission>
    </Grant>
  </AccessControlList>
</AccessControlPolicy>
END_OF_ACL
    @acl_list_md5 = Hash[@acl_list.map { |k,v| [k, Base64.encode64(Digest::MD5.digest(v)).chomp] }]
    @content_length = Hash[@acl_list.map { |k,v| [k, v.size.to_i] }]
  end

  before(:each) do # mock cannot be used by before(:all).
    @time_mock = mock(Time)
    S3Adapter::DependencyInjector.stub!(:time_now).with(no_args).and_return { @time_mock }
    @time_mock.stub!(:utc).and_return { @time_mock }
    @time_mock.stub!(:iso8601).and_return { '2011-08-26T01:14:09Z' }
  end

  context "no given valid acl list" do
    before(:all) do
      @user = 'test_user1'
      path = "/hoge/foo/bar/baz.txt?acl"
      headers = {
        "HTTP_DATE" => @time,
        "CONTENT_LENGTH" => @content_length[@user]
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, nil, headers
    end

    it "should return MissingSecurityHeader response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should              == "MissingSecurityHeader"
      xml.elements["Error/Message"].text.should           == "Your request was missing a required header"
      xml.elements["Error/MissingHeaderName"].text.should == "x-amz-acl"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context "given invalid acl list" do
    before(:all) do
      invalid_xml_acl_list = <<END_OF_ACL
<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>NoSuchBucket</Code>
  <Message>The specified bucket does not exist</Message>
  <BucketName>no_exist_bucket</BucketName>
  <RequestId>0123456789ABCDEF</RequestId>
  <HostId>cjk348cmkdwfjmjfimerccrlggkopk3coldfejhfn2343ernewnfnwnr4nnfn4jk</HostId>
</Error>
END_OF_ACL
      @user = 'test_user1'
      path = "/hoge/foo/bar/baz.txt?acl"
      headers = {
        "HTTP_DATE" => @time,
        "CONTENT_LENGTH" => @content_length[@user]
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, invalid_xml_acl_list, headers
    end

    it "should return MalformedACLError response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should    == "MalformedACLError"
      xml.elements["Error/Message"].text.should == "The XML you provided was not well-formed or did not validate against our published schema"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context "given invalid object acl owner." do
    before(:all) do
      @user = 'test_user2'
      headers = {
        'HTTP_DATE' => @time,
        "HTTP_HOST" => "no_set_acl.s3.adapter",
        "CONTENT_LENGTH" => @content_length[@user]
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/foo/bar/baz.txt?acl', headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put '/foo/bar/baz.txt?acl', @acl_list[@user], headers
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

  context "given invalid acl permission." do
    before(:all) do
      invalid_acl_permission_list = <<END_OF_ACL
<AccessControlPolicy>
  <Owner>
    <ID>NoSetACLAccessKeyId</ID>
    <DisplayName>test_user3</DisplayName>
  </Owner>
  <AccessControlList>
    <Grant>
      <Grantee xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="CanonicalUser">
        <ID>XXXXXXXXXXXXXXXXXXXX</ID>
        <DisplayName>test_user1</DisplayName>
      </Grantee>
      <Permission>HOGE</Permission>
    </Grant>
  </AccessControlList>
</AccessControlPolicy>
END_OF_ACL
      @user = 'test_user3'
      headers = {
        'HTTP_DATE' => @time,
        "HTTP_HOST" => "no_set_acl.s3.adapter",
        "CONTENT_LENGTH" => invalid_acl_permission_list.size,
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/foo/bar/baz.txt?acl', headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put '/foo/bar/baz.txt?acl', invalid_acl_permission_list, headers
    end

    it 'should return response code 400' do
      last_response.status.should == 400
    end

    it 'should return response headers' do
      last_response.header['server'].should       == 'AmazonS3'
      last_response.header['content-type'].should == 'application/xml;charset=utf-8'
    end

    it "should return MalformedACLError response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should    == "MalformedACLError"
      xml.elements["Error/Message"].text.should == "The XML you provided was not well-formed or did not validate against our published schema"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context "given invalid bucketname" do
    before(:all) do
      @user = 'test_user1'
      path = "/invalid_bucket/foo/bar/baz.txt?acl"
      headers = {
        "HTTP_DATE" => @time,
        "CONTENT_LENGTH" => @content_length[@user]
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, @acl_list[@user], headers
    end

    it "should return response code 404." do
      last_response.status.should == 404
    end

    it "should return response header." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return NoSuchBucket response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should       == "NoSuchBucket"
      xml.elements["Error/Message"].text.should    == "The specified bucket does not exist"
      xml.elements["Error/BucketName"].text.should == "invalid_bucket"
      xml.elements["Error/RequestId"].text.should be_nil
      xml.elements["Error/HostId"].text.should be_nil
    end
  end

  context "given invalid objectkey" do
    before(:all) do
      @user = 'test_user1'
      path = "/test/invalid_object?acl"
      headers = {
        "HTTP_DATE" => @time,
        "CONTENT_LENGTH" => @content_length[@user]
      }
      signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', path, headers)
      headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
      put path, @acl_list[@user], headers
    end

    it "should return response code 404." do
      last_response.status.should == 404
    end

    it "should return response header." do
      last_response.header["content-type"].should == "application/xml;charset=utf-8"
      last_response.header["server"].should       == "AmazonS3"
    end

    it "should return NoSuchKey response body." do
      xml = REXML::Document.new last_response.body
      xml.elements["Error/Code"].text.should    == "NoSuchKey"
      xml.elements["Error/Message"].text.should == "The specified key does not exist."
      xml.elements["Error/Key"].text.should     == "invalid_object"
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
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length[@user]
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/foo/bar/baz.txt?acl', @acl_list[@user], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('no_set_acl', 'foo/bar/baz.txt') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user2'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length[@user]
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/foo/bar/baz.txt?acl', @acl_list[@user], headers
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
          headers = {
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          put '/foo/bar/baz.txt?acl', @acl_list['test_user1'], headers
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

    describe "set acl specific user acl Object(WRITE_ACP)." do
      context 'Canonical user request.' do
        before(:all) do
          @user = 'test_user2'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/specific_user_object?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/specific_user_object?acl', @acl_list['test_user1'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('no_set_acl', 'specific_user_object') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/specific_user_object?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/specific_user_object?acl', @acl_list['test_user1'], headers
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
          headers = {
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @acl_list['test_user1'].size,
          }
          put '/specific_user_object?acl', @acl_list['test_user1'], headers
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

    describe "set acl authenticated user Object(WRITE_ACP)." do
      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/authenticated_user_object?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/authenticated_user_object?acl', @acl_list['test_user1'], headers
        end

        it 'should return response code 200' do
          last_response.status.should == 200
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('no_set_acl', 'authenticated_user_object') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Anonymous user request.' do
        before(:all) do
          headers = {
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          put '/authenticated_user_object?acl', @acl_list['test_user1'], headers
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

    describe "set acl all user Object(WRITE_ACP)." do
      context 'Anonymous user request.' do
        before(:all) do
          headers = {
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          put '/hoge/fuga/piyo.txt?acl', @acl_list['test_user1'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('no_set_acl', 'hoge/fuga/piyo.txt') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end
    end

    describe "set acl specific user acl Object(FULL_CONTROL)." do
      context 'Canonical user request.' do
        before(:all) do
          @user = 'test_user1'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/specfic_user_full_control?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/specfic_user_full_control?acl', @acl_list['test_user2'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('no_set_acl', 'specfic_user_full_control') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/specfic_user_full_control?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/specfic_user_full_control?acl', @acl_list['test_user2'], headers
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
          headers = {
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          put '/specfic_user_full_control?acl', @acl_list['test_user2'], headers
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

    describe "set acl authenticated user Object(FULL_CONTROL)." do
      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/no_set_acl/authenticated_user_full_control?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/authenticated_user_full_control?acl', @acl_list['test_user2'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('no_set_acl', 'authenticated_user_full_control') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Anonymous user request.' do
        before(:all) do
          headers = {
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          put '/authenticated_user_full_control?acl', @acl_list['test_user2'], headers
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

    describe "set acl all user Object(FULL_CONTROL)." do
      context 'Anonymous user request.' do
        before(:all) do
          headers = {
            "HTTP_HOST" => "no_set_acl.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          put '/full_control.txt?acl', @acl_list['test_user2'], headers
        end

        it 'should return response code 200' do
          last_response.status.should == 200
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('no_set_acl', 'full_control.txt') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
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
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user3']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/foo/bar/baz.txt?acl', @acl_list['test_user3'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user2'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user3']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/foo/bar/baz.txt?acl', @acl_list['test_user3'], headers
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
          headers = {
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user3']
          }
          put '/foo/bar/baz.txt?acl', @acl_list['test_user3'], headers
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

    describe "set acl specific user Object(WRITE_ACP)." do
      context 'Canonical user request.' do
        before(:all) do
          @user = 'test_user2'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/specific_user_object_acl?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/specific_user_object_acl?acl', @acl_list['test_user1'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('test', 'specific_user_object_acl') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/specific_user_object_acl?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/specific_user_object_acl?acl', @acl_list['test_user1'], headers
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
          headers = {
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          put '/specific_user_object_acl?acl', @acl_list['test_user1'], headers
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

    describe "set acl authenticated user Object(WRITE_ACP)." do
      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/authenticated_user_object_acl?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/authenticated_user_object_acl?acl', @acl_list['test_user1'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('test', 'authenticated_user_object_acl') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Anonymous user request.' do
        before(:all) do
          headers = {
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          put '/authenticated_user_object_acl?acl', @acl_list['test_user1'], headers
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

    describe "set acl all user Object(WRITE_ACP)." do
      context 'Anonymous user request.' do
        before(:all) do
          headers = {
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user1']
          }
          put '/hoge/fuga/piyo.txt?acl', @acl_list['test_user1'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('test', 'hoge/fuga/piyo.txt') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end
    end

    describe "set acl specific user Object(FULL_CONTROL)." do
      context 'Canonical user request.' do
        before(:all) do
          @user = 'test_user1'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/specfic_user_full_control?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/specfic_user_full_control?acl', @acl_list['test_user2'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('test', 'specfic_user_full_control') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/specfic_user_full_control?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/specfic_user_full_control?acl', @acl_list['test_user2'], headers
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
          headers = {
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          put '/specfic_user_full_control?acl', @acl_list['test_user2'], headers
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

    describe "set acl authenticated user Object(FULL_CONTROL)." do
      context 'Authenticated user request.' do
        before(:all) do
          @user = 'test_user3'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/authenticated_user_full_control_acl?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put '/authenticated_user_full_control_acl?acl', @acl_list['test_user2'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('test', 'authenticated_user_full_control_acl') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context 'Anonymous user request.' do
        before(:all) do
          headers = {
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          put '/authenticated_user_full_control_acl?acl', @acl_list['test_user2'], headers
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

    describe "set acl all user Object(FULL_CONTROL)." do
      context 'Anonymous user request.' do
        before(:all) do
          headers = {
            "HTTP_HOST" => "test.s3.adapter",
            "CONTENT_LENGTH" => @content_length['test_user2']
          }
          put '/full_control.txt?acl', @acl_list['test_user2'], headers
        end

        it 'should return response code 200' do
          last_response.should be_ok
        end

        it 'should return response headers' do
          last_response.header['server'].should == 'AmazonS3'
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('test', 'full_control.txt') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end
    end

  end

  describe "request headers" do
    context "Content-Length" do
      context "no given Content-Length header." do
        before(:all) do
          put "/test/foo/bar/baz.txt?acl"
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end

        it "should return response headers." do
          last_response.header["content-type"].should == "application/xml;charset=utf-8"
          last_response.header["server"].should       == "AmazonS3"
        end

        it "should return MissingSecurityHeader response body." do
          xml = REXML::Document.new last_response.body
          xml.elements["Error/Code"].text.should              == "MissingSecurityHeader"
          xml.elements["Error/Message"].text.should           == "Your request was missing a required header"
          xml.elements["Error/MissingHeaderName"].text.should == "x-amz-acl"
          xml.elements["Error/RequestId"].text.should be_nil
          xml.elements["Error/HostId"].text.should be_nil
        end
      end

      context "given Content-Length header size 0." do
        before(:all) do
          put "/test/foo/bar/baz.txt?acl", @acl_list['test_user3'], "CONTENT_LENGTH" => 0
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end

        it "should return response headers." do
          last_response.header["server"].should == "AmazonS3"
        end

        it "should return MissingSecurityHeader response body." do
          xml = REXML::Document.new last_response.body
          xml.elements["Error/Code"].text.should              == "MissingSecurityHeader"
          xml.elements["Error/Message"].text.should           == "Your request was missing a required header"
          xml.elements["Error/MissingHeaderName"].text.should == "x-amz-acl"
          xml.elements["Error/RequestId"].text.should be_nil
          xml.elements["Error/HostId"].text.should be_nil
        end
      end

      context "given Content-Length header less than content size." do
        before(:all) do
          put "/test/foo/bar/baz.txt?acl", @acl_list['test_user3'], "CONTENT_LENGTH" => @content_length['test_user3'] - 10
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end

        it "should return response headers." do
          last_response.header["server"].should == "AmazonS3"
        end

        it "should return MalformedACLError response body." do
          xml = REXML::Document.new last_response.body
          xml.elements["Error/Code"].text.should    == "MalformedACLError"
          xml.elements["Error/Message"].text.should == "The XML you provided was not well-formed or did not validate against our published schema"
          xml.elements["Error/RequestId"].text.should be_nil
          xml.elements["Error/HostId"].text.should be_nil
        end
      end

      context "given invalid Content-Length header." do
        before(:all) do
          put "/test/foo/bar/baz.txt?acl", @acl_list['test_user3'], "CONTENT_LENGTH" => "hoge"
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end

        it "should return response headers." do
          last_response.header["server"].should == "AmazonS3"
        end

        it "should return response body." do
          last_response.body.should be_empty
        end
      end

    end

    context "Content-MD5" do
      context "given correct Content-MD5 header." do
        before(:all) do
          @user = 'test_user1'
          headers = {
            "HTTP_DATE" => @time,
            "HTTP_HOST" => "test.s3.adapter",
            "HTTP_CONTENT_MD5" => @acl_list_md5['test_user3'],
            "CONTENT_LENGTH"   => @content_length['test_user3']
          }
          signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', '/test/foo/bar/baz.txt?acl', headers)
          headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
          put "/foo/bar/baz.txt?acl", @acl_list['test_user3'], headers
        end

        it "should return response code 200." do
          last_response.status.should == 200
        end

        it "should return response headers." do
          last_response.header["server"].should == "AmazonS3"
        end

        it 'should return response body' do
          last_response.body.should be_empty
        end

        it 'should set acl list' do
          acl = find_by_bucket_and_path('test', 'full_control.txt') { |obj| obj.acl }
          acl['account'].size.should == 1
          acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
        end
      end

      context "given unmatch Content-MD5 header." do
        before(:all) do
          put "/test/foo/bar/baz.txt?acl", @acl_list['test_user3'],
            "HTTP_CONTENT_MD5" => "hoge",
            "CONTENT_LENGTH"   => @content_length['test_user3']
        end

        it "should return response code 400." do
          last_response.status.should == 400
        end

        it "should return response headers." do
          last_response.header["content-type"].should == "application/xml;charset=utf-8"
          last_response.header["server"].should       == "AmazonS3"
        end

        it "should return BadDigest response body." do
          xml = REXML::Document.new last_response.body
          xml.elements["Error/Code"].text.should == "BadDigest"
          xml.elements["Error/Message"].text.should == "The Content-MD5 you specified did not match what we received."
          xml.elements["Error/ExpectedDigest"].text.should == "hoge"
          xml.elements["Error/CalculatedDigest"].text.should == @acl_list_md5['test_user3']
          xml.elements["Error/RequestId"].text.should be_nil
          xml.elements["Error/HostId"].text.should be_nil
        end
      end
    end

  end

  describe 'x-amz-acl header' do
    before(:all) do
      @user = 'test_user1'
      @path = '/test/foo/bar/baz.txt?acl'
    end

    context "given request body" do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time,
          'HTTP_X_AMZ_ACL' => 'private',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, @acl_list['test_user3'], headers
      end

      it "should return UnexpectedContent response body." do
        xml = REXML::Document.new last_response.body
        xml.elements["Error/Code"].text.should == "UnexpectedContent"
        xml.elements["Error/Message"].text.should == "This request does not support content"
        xml.elements["Error/RequestId"].text.should be_nil
        xml.elements["Error/HostId"].text.should be_nil
      end
    end

    context 'given private' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time,
          'HTTP_X_AMZ_ACL' => 'private',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, nil, headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should_not be_nil
      end

      it 'full_control is added to request user.' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

    context 'given public-read' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time,
          'HTTP_X_AMZ_ACL' => 'public-read',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, nil, headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should_not be_nil
      end

      it 'full_control is added to request user.' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'read is added to guest' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should == [S3Adapter::Acl::READ]
      end
    end

    context 'given public-read-write' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time,
          'HTTP_X_AMZ_ACL' => 'public-read-write',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, nil, headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should_not be_nil
      end

      it 'full_control is added to request user.' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'read and write are added to guest' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should == [S3Adapter::Acl::READ, S3Adapter::Acl::WRITE]
      end
    end

    context 'given authenticated-read' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time,
          'HTTP_X_AMZ_ACL' => 'authenticated-read',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, nil, headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 1
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should_not be_nil
      end

      it 'full_control is added to request user.' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'read is added to authenticated' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should == [S3Adapter::Acl::READ]
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

    context 'given bucket-owner-read' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time,
          'HTTP_X_AMZ_ACL' => 'bucket-owner-read',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, nil, headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 2
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should_not be_nil
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
      end

      it 'full_control is added to request user.' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'read is added to bucket owner.' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::READ]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

    context 'given bucket-owner-full-control' do
      before(:all) do
        headers = {
          'HTTP_DATE'      => @time,
          'HTTP_X_AMZ_ACL' => 'bucket-owner-full-control',
        }
        signature = aws_signature(@users[@user]['secret-access-key'], 'PUT', @path, headers)
        headers['HTTP_AUTHORIZATION'] = "AWS #{@users[@user]['access-key-id']}:#{signature}"
        put @path, nil, headers
      end

      it 'only AStringOfAccessKeyId is set to account' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account'].size.should == 2
        acl['account']['AStringOfAccessKeyId'].should_not be_nil
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should_not be_nil
      end

      it 'full_control is added to request user.' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['XXXXXXXXXXXXXXXXXXXX'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'full_control is added to bucket owner.' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['account']['AStringOfAccessKeyId'].should == [S3Adapter::Acl::FULL_CONTROL]
      end

      it 'authenticated is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['authenticated'].should be_nil
      end

      it 'guest is set to nothing' do
        acl = find_by_bucket_and_path('test', 'foo/bar/baz.txt') { |obj| obj.acl }
        acl['guest'].should be_nil
      end
    end

  end

  after(:all) do
    FileUtils.rm_r S3Adapter::Adapter::BASE if File.exists?(S3Adapter::Adapter::BASE)
  end

end
