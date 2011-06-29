xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "NoSuchKey"
  xml.Message "The specified key does not exist."
  xml.Key @object
  xml.RequestId
  xml.HostId
end
