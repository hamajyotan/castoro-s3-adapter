xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "MalformedACLError"
  xml.Message "The XML you provided was not well-formed or did not validate against our published schema"
  xml.RequestId
  xml.HostId
end
