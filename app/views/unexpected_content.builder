xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "UnexpectedContent"
  xml.Message "This request does not support content"
  xml.RequestId
  xml.HostId
end
