xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "AccessDenied"
  xml.Message @message
  xml.RequestId
  xml.HostId
end
