xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "MissingSecurityHeader"
  xml.Message "Your request was missing a required header"
  xml.MissingHeaderName @missing_header_name
  xml.RequestId
  xml.HostId
end
