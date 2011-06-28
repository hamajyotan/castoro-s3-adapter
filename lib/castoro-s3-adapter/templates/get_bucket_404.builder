xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "NoSuchBucket"
  xml.Message "The specified bucket does not exist"
  xml.BucketName @bucket
  xml.RequestId
  xml.HostId
end
