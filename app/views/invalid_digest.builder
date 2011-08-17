xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "InvalidDigest"
  xml.Message "The Content-MD5 you specified was invalid."
  xml.RequestId
  xml.Content_MD5 @content_md5
  xml.HostId
end
