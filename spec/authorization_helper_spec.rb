
require File.expand_path('../../spec/spec_helper', __FILE__)

describe S3Adapter::AuthorizationHelper do
  include S3Adapter::AuthorizationHelper

  before(:all) do
    User.delete_all
    User.new { |u|
      u.access_key_id = "A2E9126B863648840AB1"
      u.display_name = "test_user"
      u.secret = "cbUUiHIkVY2jv2wwI1zcEQqLMKNmfN6BcIrphgq9"
      u.save
    }
  end

  describe "#authorization" do

    context "given valid method, bucket, object and headers" do
      it "should get user instance" do
        user = authorization "GET",
                             "castoro",
                             "foo/bar/baz.txt",
                             "Date" => "Wed, 12 Oct 2009 17:50:00 GMT",
                             "Authorization" => "AWS A2E9126B863648840AB1:mjE2xBNgrBgt8thurJzCR58QTZ4="
        user.should_not == nil
        user.display_name.should == "test_user"
      end
    end

  end

  describe "#anonymous_user?" do

    context "given Authorization header" do
      it "should return false" do
        header = { "Authorization" => "AWS A2E9126B863648840AB1:mjE2xBNgrBgt8thurJzCR58QTZ4=" }
        anonymous_user?(header).should == false     
      end
    end

    context "not given Authorization header" do
      it "should return true" do
        header = { "foo" => "bar", "baz" => "qux" }
        anonymous_user?(header).should == true
      end
    end

  end

end

