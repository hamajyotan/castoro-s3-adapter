xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "MissingContentLength"
  xml.Message "You must provide the Content-Length HTTP header."
  xml.RequestId
  xml.HostId
end
