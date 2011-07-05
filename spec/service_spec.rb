
require File.dirname(__FILE__) + "/spec_helper.rb"

require "fileutils"
require "net/http"
require "rexml/document"
require "aws/s3"

describe Castoro::S3Adapter::Service do
  before do
    # preset castoro test files.
    @tmp = File.dirname(__FILE__) + "/../tmp/"
    FileUtils.mkdir_p @tmp
    FileUtils.mkdir_p File.join(@tmp, "host1", "1.1.1")
    File.open(File.join(@tmp, "host1", "1.1.1", "hoge.txt"), "w") { |f| f.write "hoge.txt\n12345\nABC" }
    File.open(File.join(@tmp, "host1", "1.1.1", "fuga.txt"), "w") { |f| f.write "h" }

    @file_info = Hash.new { |h, k|
      st = File.stat k
      h[k] = {
        :last_modified => st.mtime.utc.iso8601,
        :httpdate => st.mtime.httpdate,
        :etag => sprintf("%x-%x-%x", st.ino, st.size, st.mtime),
      }
    }

    # for test.
    Castoro::S3Adapter::Adaptable::BASE.replace @tmp

    # mock for castoro-client
    @client = mock Castoro::Client
    @client.stub!(:new).and_return(@client)
    Castoro::Client.stub!(:new).and_return(@client)

    # castoro-client methods implementation for mock
    client_alive = false
    sid = 0

    @client.stub!(:open).and_return {
      raise Castoro::ClientError, "client already opened." if client_alive
      client_alive = true
    }
    @client.stub!(:close).and_return {
      raise Castoro::ClientError, "client already closed." unless client_alive
      client_alive = false
    }
    @client.stub!(:opened?).and_return { !! client_alive }
    @client.stub!(:closed?).and_return { ! @client.opened? }
    @client.stub!(:sid).and_return { sid }

    @client.stub!(:get).and_return { nil }
    @client.stub!(:create).and_return { nil }
    @client.stub!(:create_direct).and_return { nil }
    @client.stub!(:delete).and_return { nil }

    @client.stub!(:get).with("1.1.1").and_return {
      { "host1" => "1.1.1" }
    }

    # start adapter.
    @l = Logger.new nil
    @s = Castoro::S3Adapter::Service.new @l
    @s.start
    sleep 1.0

    # aws-s3 settings.
    AWS::S3::Base.establish_connection!(
      :server => "127.0.0.1",
      :port => 8080,
      :access_key_id => "castoro",
      :secret_access_key => "castoro"
    )
  end

  describe "net/http access" do
    describe "GET Bucket" do
      it "The file that exists in Bucket should be able to enumerate." do
        Net::HTTP.start("127.0.0.1", 8080) { |http|
          response = http.get("/castoro/?prefix=1.1.1/")

          response.code.should == "200"

          xml = REXML::Document.new response.body
          xml.elements["ListBucketResult/Name"].text.should == "castoro"
          xml.elements["ListBucketResult/Prefix"].text.should == "1.1.1/"
          xml.elements["ListBucketResult/Marker"].text.should == nil
          xml.elements["ListBucketResult/MaxKeys"].text.should == "1000"
          xml.elements["ListBucketResult/IsTruncated"].text.should == "false"

          xml.elements["ListBucketResult/Contents[1]/Key"].text.should == "1.1.1/"
          xml.elements["ListBucketResult/Contents[1]/LastModified"].text.should == @file_info[File.join(@tmp, "host1", "1.1.1")][:last_modified]
          xml.elements["ListBucketResult/Contents[1]/ETag"].text.should == @file_info[File.join(@tmp, "host1", "1.1.1")][:etag]
          xml.elements["ListBucketResult/Contents[1]/Size"].text.should == "0"
          xml.elements["ListBucketResult/Contents[1]/StorageClass"].text.should == "STANDARD"

          xml.elements["ListBucketResult/Contents[2]/Key"].text.should == "1.1.1/fuga.txt"
          xml.elements["ListBucketResult/Contents[2]/LastModified"].text.should == @file_info[File.join(@tmp, "host1", "1.1.1", "fuga.txt")][:last_modified]
          xml.elements["ListBucketResult/Contents[2]/ETag"].text.should == @file_info[File.join(@tmp, "host1", "1.1.1", "fuga.txt")][:etag]
          xml.elements["ListBucketResult/Contents[2]/Size"].text.should == "1"
          xml.elements["ListBucketResult/Contents[2]/StorageClass"].text.should == "STANDARD"

          xml.elements["ListBucketResult/Contents[3]/Key"].text.should == "1.1.1/hoge.txt"
          xml.elements["ListBucketResult/Contents[3]/LastModified"].text.should == @file_info[File.join(@tmp, "host1", "1.1.1", "hoge.txt")][:last_modified]
          xml.elements["ListBucketResult/Contents[3]/ETag"].text.should == @file_info[File.join(@tmp, "host1", "1.1.1", "hoge.txt")][:etag]
          xml.elements["ListBucketResult/Contents[3]/Size"].text.should == "18"
          xml.elements["ListBucketResult/Contents[3]/StorageClass"].text.should == "STANDARD"
        }
      end

      it "The file that not exists in Bucket should be ale to null enumerate." do
        Net::HTTP.start("127.0.0.1", 8080) { |http|
          response = http.get("/castoro/?prefix=1.1.2/")

          response.code.should == "200"

          xml = REXML::Document.new response.body
          xml.elements["ListBucketResult/Name"].text.should == "castoro"
          xml.elements["ListBucketResult/Prefix"].text.should == "1.1.2/"
          xml.elements["ListBucketResult/Marker"].text.should == nil
          xml.elements["ListBucketResult/MaxKeys"].text.should == "1000"
          xml.elements["ListBucketResult/IsTruncated"].text.should == "false"
        }
      end
  
      context "given unknown bucket." do
        it "should return NoSuchBucket response" do
          Net::HTTP.start("127.0.0.1", 8080) { |http|
            response = http.get("/not_exists_bucket/?prefix=1.1.1/")
  
            response.code.should == "404"
  
            xml = REXML::Document.new response.body
            xml.elements["Error/Code"].text.should == "NoSuchBucket"
            xml.elements["Error/Message"].text.should == "The specified bucket does not exist"
            xml.elements["Error/BucketName"].text.should == "not_exists_bucket"
            xml.elements["Error/RequestId"].text.should == nil
            xml.elements["Error/HostId"].text.should == nil
          }
        end
      end
    end
  
    describe "GET Object" do
      it "Object should be able to be downloaded." do
        Net::HTTP.start("127.0.0.1", 8080) { |http|
          response = http.get("/castoro/1.1.1/hoge.txt")

          response.code.should == "200"

          response["last-modified"].should === @file_info[File.join(@tmp, "host1", "1.1.1", "hoge.txt")][:httpdate]
          response["etag"].should == @file_info[File.join(@tmp, "host1", "1.1.1", "hoge.txt")][:etag]
          response.body.should == "hoge.txt\n12345\nABC"
        }
      end
  
      context "given unknown object." do
        it "should return NoSuchKey response" do
          Net::HTTP.start("127.0.0.1", 8080) { |http|
            response = http.get("/castoro/1.1.1/foo.txt")
  
            response.code.should == "404"
  
            xml = REXML::Document.new response.body
            xml.elements["Error/Code"].text.should == "NoSuchKey"
            xml.elements["Error/Message"].text.should == "The specified key does not exist."
            xml.elements["Error/Key"].text.should == "1.1.1/foo.txt"
            xml.elements["Error/RequestId"].text.should == nil
            xml.elements["Error/HostId"].text.should == nil
          }
        end
      end

      context "given unknown bucket." do
        it "should return NoSuchBucket response" do
          Net::HTTP.start("127.0.0.1", 8080) { |http|
            response = http.get("/not_exists_bucket/1.1.1/foo.txt")
  
            response.code.should == "404"
  
            xml = REXML::Document.new response.body
            xml.elements["Error/Code"].text.should == "NoSuchBucket"
            xml.elements["Error/Message"].text.should == "The specified bucket does not exist"
            xml.elements["Error/BucketName"].text.should == "not_exists_bucket"
            xml.elements["Error/RequestId"].text.should == nil
            xml.elements["Error/HostId"].text.should == nil
          }
        end
      end
    end
  end

  describe "aws/s3 access" do
    describe "GET Bucket" do
      it "The file that exists in Bucket should be able to enumerate." do
        objects = AWS::S3::Bucket.objects("castoro/?prefix=1.1.1/")
  
        objects.size.should == 3
        objects[0].key.should == "1.1.1/"
        objects[0].size.should == "0"
        objects[1].key.should == "1.1.1/fuga.txt"
        objects[1].size.should == 1
        objects[2].key.should == "1.1.1/hoge.txt"
        objects[2].size.should == 18
      end
  
      context "given unknown bucket." do
        it "should return NoSuchBucket response" do
          objects = AWS::S3::Bucket.objects("castoro/?prefix=1.1.2/")
          objects.should == []
        end
      end
    end
  
    describe "GET Object" do
      it "Object should be able to be downloaded." do
        value = AWS::S3::S3Object.value("1.1.1/hoge.txt", "castoro")
        value.response.code.should == 200
        value.should == "hoge.txt\n12345\nABC"
      end
  
      context "given unknown bucket." do
        it "should return NoSuchBucket response" do
          value = AWS::S3::S3Object.value("1.1.2/foo.txt", "castoro")
          value.response.code.should == 404
        end
      end
  
      context "given unknown object." do
        it "should return NoSuchKey response" do
          value = AWS::S3::S3Object.value("1.1.1/foo.txt", "castoro")
          value.response.code.should == 404
        end
      end
    end
  end

  after do
    @s.stop
  end
end

