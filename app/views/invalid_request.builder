xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "InvalidRequest"
  xml.Message "Request specific response headers cannot be used for anonymous GET requests."
  xml.RequestId
  xml.HostId
end
