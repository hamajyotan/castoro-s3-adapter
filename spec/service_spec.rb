
require File.dirname(__FILE__) + "/spec_helper.rb"

require "fileutils"
require "aws/s3"

describe Castoro::S3Adapter::Service do
  before do
    # preset castoro test files.
    tmp = File.dirname(__FILE__) + "/../tmp"
    FileUtils.mkdir_p tmp
    FileUtils.mkdir_p File.join(tmp, "host1", "1.1.1")
    File.open(File.join(tmp, "host1", "1.1.1", "hoge.txt"), "w") { |f| f.write "hoge.txt\n12345\nABC" }
    File.open(File.join(tmp, "host1", "1.1.1", "fuga.txt"), "w") { |f| f.write "h" }

    # for test.
    Castoro::S3Adapter::Adaptable::BASE.replace tmp

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

  after do
    @s.stop
  end
end

